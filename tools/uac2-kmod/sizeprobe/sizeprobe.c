// SPDX-License-Identifier: GPL-2.0
/*
 * sizeprobe.c —— 结构体尺寸指纹（不加载，仅编译后用 `nm -S` 读符号大小）
 *
 * 为什么需要它
 * ------------
 * `struct module` 只是一个 ABI。真正危险的是：`usb_uac2.ko` 是**真驱动**，
 * 它会去读写 ALSA / USB 那些**内含 spinlock_t / struct mutex 的内核结构体**。
 * 这些结构体里任何一个成员的尺寸不对，整块内存的字段偏移就全错 ——
 * 那不是"模块加载失败"，而是**按错误偏移读写内核结构体，真的会搞坏内核**。
 *
 * 所以「配置是否与厂商内核一致」必须变成可测量的事实。做法：
 *   本文件把一批结构体的 sizeof 编成符号大小   ← CI 里 `nm -S` 读出来
 *   设备的 `/proc/slabinfo` 的 objsize 列     ← 内核自己 `sizeof()` 的实参
 * 两边一比，不一致的结构体立刻暴露。
 *
 * 注意
 * ----
 * - 数组长度必须是编译期常量，`sizeof` 满足；用 `__attribute__((used))`
 *   防止被优化掉（否则 nm 里没有这个符号）。
 * - 这些符号会落在 .bss，nm 里的类型是 `B`。
 * - 每个名字前缀 `penmods_sz_`，方便过滤。
 */
#include <linux/module.h>
#include <linux/sched.h>
#include <linux/fs.h>
#include <linux/fdtable.h>
#include <linux/dcache.h>
#include <linux/mm.h>
#include <linux/pid.h>
#include <linux/cred.h>
#include <linux/rmap.h>
#include <linux/wait.h>
#include <linux/kobject.h>
#include <linux/spinlock.h>
#include <linux/mutex.h>
#include <linux/rwsem.h>
#include <linux/semaphore.h>
#include <linux/completion.h>
#include <sound/core.h>
#include <sound/pcm.h>

/* ══════════════════════════════════════════════════════════════════════════
 * 编译期硬断言：这三条一旦不满足，**直接让 CI 编不过**，而不是产出错布局
 * ══════════════════════════════════════════════════════════════════════════
 *
 * 为什么必须是编译期：`make olddefconfig` 的依赖解析是**静默**的。
 * 2026-10-03 的真机 oops 就是这么来的 —— workflow 里写了 `--enable SND`，
 * 但漏了 `--enable SOUND`（`config SND depends on SOUND`），于是 SND 被静默
 * 撤销、`CONFIG_SND_VERBOSE_PROCFS` 变 n、`struct snd_pcm_str` 少两个指针，
 * 我们算出的 offsetof(snd_pcm, private_data) 比内核小 32 字节：
 *     alsa_uac2_init() 的 `pcm->private_data = uac2` 写错字段
 *     → 内核在真偏移处读到 kzalloc 的 0，拷给 substream
 *     → uac2_pcm_open+0x20 解引用 NULL → panic_on_oops=1 → 设备重启
 * 判据（设备侧实测）：
 *     /proc/asound/ 里有 `Loopback` 目录 + `card0/pcm0p/sub0/info` 层级
 *         ⇒ CONFIG_SND_VERBOSE_PROCFS = y
 *     /proc/asound/ 下没有 `oss`，kallsyms 里 snd_pcm_oss* 计数 0
 *         ⇒ CONFIG_SND_PCM_OSS = n
 */
#ifndef CONFIG_SOUND
#error "CONFIG_SOUND 必须为 y —— 否则 CONFIG_SND 会被 make olddefconfig 静默撤销"
#endif
#ifndef CONFIG_SND
#error "CONFIG_SND 必须为 y —— 否则 ALSA 结构体布局与设备内核不一致"
#endif
#ifndef CONFIG_SND_VERBOSE_PROCFS
#error "CONFIG_SND_VERBOSE_PROCFS 必须为 y（设备实测）—— 否则 struct snd_pcm_str 少 proc_root/proc_info_entry 两个指针，private_data 偏移小 32"
#endif
#if IS_ENABLED(CONFIG_SND_PCM_OSS)
#error "CONFIG_SND_PCM_OSS 必须为 n（设备 /proc/asound 下无 oss）—— 否则 struct snd_pcm_str 多一段 oss"
#endif

#define SZT(n, t) char penmods_sz_##n[sizeof(t)] __attribute__((used))
/* offsetof 用「数组长度」编码：`nm -S` 读到的 size 就是那个偏移。
 * （nm 只读 symbol size、读不到 symbol value，所以用这个技巧把它变成可量测的。） */
#define SZO(n, t, f) char penmods_off_##n[offsetof(t, f)] __attribute__((used))

/* ── 锁原语：这三个是「DEBUG_SPINLOCK 是否打开」的直接判据 ──
 * spinlock_t    : 4  (无调试) / 24 (DEBUG_SPINLOCK)
 * struct mutex  : 40 (无调试) / 64 (DEBUG_SPINLOCK)
 * struct semaphore: 24        / 48
 * 厂商 8723ds.ko 的 .bss 里有 _lock(=struct mutex) 64、_sema(=struct semaphore) 48，
 * 直接坐实了 DEBUG_SPINLOCK=y。
 */
SZT(spinlock_t, spinlock_t);
SZT(rwlock_t, rwlock_t);
SZT(mutex, struct mutex);
SZT(rw_semaphore, struct rw_semaphore);
SZT(semaphore, struct semaphore);
SZT(completion, struct completion);
SZT(wait_queue_head, wait_queue_head_t);

/* ── 普通内核结构体：全部能对上 /proc/slabinfo 的 objsize ── */
SZT(kobject, struct kobject);
SZT(task_struct, struct task_struct);
SZT(signal_struct, struct signal_struct);
SZT(sighand_struct, struct sighand_struct);
SZT(mm_struct, struct mm_struct);
SZT(vm_area_struct, struct vm_area_struct);
SZT(files_struct, struct files_struct);
SZT(file, struct file);
SZT(dentry, struct dentry);
SZT(pid, struct pid);
SZT(cred, struct cred);
SZT(anon_vma, struct anon_vma);
/* 注：struct kmem_cache 在模块可见的头文件里是**不完整类型**，不能取 sizeof。 */

/* ── 几个"底座"类型：核对指针宽度与基本约定（必须 8 / 16）── */
SZT(voidp, void *);
SZT(long, long);
SZT(list_head, struct list_head);
SZT(hlist_node, struct hlist_node);
SZT(rb_node, struct rb_node);
SZT(atomic_long, atomic_long_t);

/* ── ALSA PCM：第六处 ABI（2026-10-03 真机 oops）的直接判据 ──
 *
 * `usb_uac2.ko` 会写 `pcm->private_data = uac2`（alsa_uac2_init），
 * 内核会读同一个字段拷进 substream->private_data，我们的 uac2_pcm_open 再读它。
 * 这两个偏移完全由 `struct snd_pcm_str` 的长度决定：
 *     streams[2] 尾部 + CONFIG_SND_VERBOSE_PROCFS 的 2 个指针（各 16B × 2）
 *     streams[2] 尾部 + CONFIG_SND_PCM_OSS 的 struct snd_pcm_oss_stream（× 2）
 * 所以下面这几个数字就是「我们的布局 vs 设备内核布局」是否一致的读数。
 */
SZT(snd_pcm, struct snd_pcm);
SZT(snd_pcm_str, struct snd_pcm_str);
SZT(snd_pcm_substream, struct snd_pcm_substream);
SZT(snd_pcm_runtime, struct snd_pcm_runtime);
SZO(snd_pcm_streams,                struct snd_pcm, streams);
SZO(snd_pcm_open_mutex,             struct snd_pcm, open_mutex);
SZO(snd_pcm_open_wait,              struct snd_pcm, open_wait);
SZO(snd_pcm_private_data,           struct snd_pcm, private_data);
SZO(snd_pcm_private_free,           struct snd_pcm, private_free);
SZO(snd_pcm_str_proc_root,          struct snd_pcm_str, proc_root);
SZO(snd_pcm_str_proc_info_entry,    struct snd_pcm_str, proc_info_entry);
/* 注：不量 offsetof(snd_pcm_substream, pcm) —— 它是 0，会变成零长数组（GNU 扩展，
 * 在 -Wall -Werror 的既有风格下是噪音），而且它本来就是第一个成员，没有信息量。 */
SZO(snd_pcm_substream_pstr,         struct snd_pcm_substream, pstr);
SZO(snd_pcm_substream_private_data, struct snd_pcm_substream, private_data);

static int __init sizeprobe_init(void)
{
	return 0;
}

static void __exit sizeprobe_exit(void)
{
}

module_init(sizeprobe_init);
module_exit(sizeprobe_exit);

MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("PenMods struct-size fingerprint probe (never loaded)");
