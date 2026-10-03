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
#include <linux/device.h>
#include <linux/spinlock.h>
#include <linux/mutex.h>
#include <linux/rwsem.h>
#include <linux/semaphore.h>
#include <linux/completion.h>
#include <linux/workqueue.h>
#include <linux/timer.h>
#include <linux/pm.h>
#include <linux/pm_qos.h>
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
#ifdef CONFIG_SND_PCM_OSS_MODULE
#error "CONFIG_SND_PCM_OSS_MODULE（=m 形态）也必须不定义 —— 它的判断和 y 走同一个 #if"
#endif
/* CONFIG_SND_PCM_XRUN_DEBUG 在 PROCFS 块内**再嵌一层**，会插 16 字节：
 *     unsigned int xrun_debug;                // 4 (+4 对齐)
 *     struct snd_info_entry *proc_xrun_debug_entry;  // 8
 * 它是 `default y`，但 `depends on SND_DEBUG`，而 SND_DEBUG 没有 default ⇒
 * 实际为 n。设备侧实测：/proc/asound/card0/pcm0p/sub0/ 下没有 xrun_debug。 */
#if IS_ENABLED(CONFIG_SND_PCM_XRUN_DEBUG)
#error "CONFIG_SND_PCM_XRUN_DEBUG 必须为 n（设备 sub0 下无 xrun_debug）—— 否则 struct snd_pcm_str 多 16 字节"
#endif
#ifdef CONFIG_SND_DEBUG
#error "CONFIG_SND_DEBUG 必须为 n —— 它会让 SND_PCM_XRUN_DEBUG 自动变 y（default y），从而改变 struct snd_pcm_str"
#endif

/* ══════════════════════════════════════════════════════════════════════════
 * 第七处 ABI：CONFIG_TIMER_STATS（2026-10-03 第二次真机 oops 的真根因）
 * ══════════════════════════════════════════════════════════════════════════
 *
 * 判据（设备侧四方独立证据，全部只读）：
 *   A) `/proc/timer_stats` 存在，内容为
 *        Timer Stats Version: v0.3
 *        Sample period: 0.000 s
 *        Collection: inactive
 *   B) /proc/kallsyms 里 tstats_open / tstats_show / tstats_write /
 *      init_tstats_procfs 四个**静态**符号都在
 *   C) kernel/time/Makefile:12  obj-$(CONFIG_TIMER_STATS) += timer_stats.o
 *   D) lib/Kconfig.debug:896 `config TIMER_STATS` 的 help 原文写着
 *        "The statistics can be read from /proc/timer_stats"  ← 与 A) 逐字吻合
 *   ⇒ 设备内核 CONFIG_TIMER_STATS = y
 *
 * 后果链（这是本项目第二次被 TIMER_STATS 咬）：
 *     struct timer_list 尾部 +32
 *         #ifdef CONFIG_TIMER_STATS
 *             int  start_pid; void *start_site; char start_comm[16];
 *         #endif
 *       → struct delayed_work  +32
 *       → struct pm_qos_request 144 → 176
 *       → offsetof(struct snd_pcm_substream, runtime) 280 → 312
 *   内核在 snd_pcm_attach_substream 里按**它的** 312 写 substream->runtime，
 *   我们在 uac2_pcm_open 里按**我们的** 280 去读 ⇒ 读到 kzalloc 出来的 0
 *   ⇒ uac2_pcm_open+0x40 的 `stp x4,x5,[x21,#0x180]`（runtime->hw）解引用
 *     NULL（fault 地址正好 0x180）⇒ panic_on_oops=1 ⇒ 设备重启。
 *
 * ⚠️ 它**同时**改变 struct device：`struct device` 里内嵌
 *    `struct dev_pm_info power`，而 dev_pm_info 在 `#ifdef CONFIG_PM` 里有
 *    `struct timer_list suspend_timer;` ⇒ +32。
 *    所以打开 TIMER_STATS 之后**必须同时把 MSI 关掉（−24）**，
 *    sizeof(struct device) 才会回到设备实测的 792（两条断言的耦合见下）。
 */
#ifndef CONFIG_TIMER_STATS
#error "CONFIG_TIMER_STATS 必须为 y（设备 /proc/timer_stats 存在）—— 否则 struct timer_list 少 32 字节：snd_pcm_substream.runtime 会算成 280（内核是 312），aplay 必 oops"
#endif

/* ── 同时必须把 MSI 关掉（2026-10-03 修正；原来写的是 --enable，方向反了）──
 * 设备侧判据：
 *     /sys/devices/platform/ 下每个 msi_irqs   一个都没有（count = 0）
 *     /sys/bus/pci 不存在                ⇒ CONFIG_PCI = n
 *     kallsyms 里 msi_domain_alloc_irqs / msi_create_irq_domain 全无
 *   ⇒ 没有 PCIe 的 SoC 不会开 MSI。
 * （`of_msi_configure` 在 kallsyms 里确实有，但那是**假证据**：
 *   drivers/of/irq.c 里该函数没有任何 MSI 守卫，它调用的 dev_set_msi_domain()
 *   是 device.h 里的 static inline，MSI 关掉时退化成空操作 ⇒ 符号恒存在。）
 * 开着的话 struct device 会多 msi_list(16) + msi_domain(8) = 24 字节，
 * 而这 24 字节正是当年被误判成"厂商私有 +8"的那笔账的另一半。 */
#if IS_ENABLED(CONFIG_GENERIC_MSI_IRQ)
#error "CONFIG_GENERIC_MSI_IRQ 必须为 n（设备 /sys/devices/platform/ 下每个 msi_irqs 均为空）—— 否则 struct device 多 16 字节（msi_list）"
#endif
#if IS_ENABLED(CONFIG_GENERIC_MSI_IRQ_DOMAIN)
#error "CONFIG_GENERIC_MSI_IRQ_DOMAIN 必须为 n（设备无 PCIe、无 msi_domain）—— 否则 struct device 多 8 字节（msi_domain）"
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
 * 这个偏移完全由 `struct snd_pcm_str` 的长度决定，而 4.4 的定义是
 * （include/sound/pcm.h，已核对上游 v4.4 原文）：
 *
 *     struct snd_pcm_str {
 *         int stream;                          // 0
 *         struct snd_pcm *pcm;                 // 8
 *         unsigned int substream_count;        // 16
 *         unsigned int substream_opened;       // 20
 *         struct snd_pcm_substream *substream; // 24
 *     #if defined(CONFIG_SND_PCM_OSS) || defined(CONFIG_SND_PCM_OSS_MODULE)
 *         struct snd_pcm_oss_stream oss;       // ← OSS 开关（设备 = n）
 *     #endif
 *     #ifdef CONFIG_SND_VERBOSE_PROCFS
 *         struct snd_info_entry *proc_root;        // 32
 *         struct snd_info_entry *proc_info_entry;  // 40
 *     #ifdef CONFIG_SND_PCM_XRUN_DEBUG
 *         unsigned int xrun_debug;                 // ← 再一层嵌套（设备 = n）
 *         struct snd_info_entry *proc_xrun_debug_entry;
 *     #endif
 *     #endif
 *         struct snd_kcontrol *chmap_kctl;     // 48
 *         struct device dev;                   // 56 ★ 无条件，**内嵌整个 struct device**
 *     };
 *
 * 两条容易踩的坑（我第一次就都踩了）：
 *   ① `chmap_kctl` 和 `dev` 是**无条件**成员，不是指针，`dev` 是**一整个
 *      struct device**（设备实测 792 字节，靠 TIMER_STATS=y + MSI=n 得到，
 *      不再有任何占位补丁）——
 *      所以 `sizeof(snd_pcm_str) = 56 + sizeof(struct device) = 848`。
 *      这还意味着 **`struct device` 的大小会直接决定 `struct snd_pcm` 的布局**，
 *      第五处 ABI（struct device 的成员偏移）和第六处是**耦合**的。
 *   ② `CONFIG_SND_PCM_XRUN_DEBUG`（`default y`，但 `depends on SND_DEBUG`，
 *      而 SND_DEBUG 无 default ⇒ 实际为 n）会再插 16 字节。
 *
 * 推导（设备实测：VERBOSE_PROCFS=y、OSS=n、XRUN_DEBUG=n、mutex=64、device=792）：
 *     streams      = 184            （id[64] 到 36、name[80] 到 180，对齐 8）
 *     snd_pcm_str  = 848            = 56 + 792
 *     open_mutex   = 1880           = 184 + 2×848
 *     open_wait    = 1944           = 1880 + 64
 *     private_data = 1984 ★         = 1944 + 40(wait_queue_head_t)
 *     private_free = 1992
 *     sizeof(pcm)  = 2008           = 2000 + bool + bool，对齐 8
 *
 * 反过来算当时（CONFIG_SND 没开）的错位：VERBOSE_PROCFS 宏未定义 ⇒ 少两个
 * 指针 ⇒ snd_pcm_str = 832 ⇒ private_data = 1952，比内核的 1984 **少 32**
 * —— 与 oops 现场（内核对、我们偏 32，内核读到 kzalloc 的 0）完全吻合。
 */
SZT(device, struct device);
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

/* ── 第七处 ABI（CONFIG_TIMER_STATS）在本侧的镜像 ──
 *
 * TIMER_STATS=y ⇒ timer_list 80（否则 48）
 *             ⇒ delayed_work 128（否则 96）
 *             ⇒ pm_qos_request 176（否则 144）
 * 这三个数字是"配置真的生效了"最直接的证据 —— 只要有一个是括号里的旧值，
 * 说明 --enable TIMER_STATS 又被 olddefconfig 静默撤掉了。 */
SZT(timer_list,     struct timer_list);
SZT(delayed_work,   struct delayed_work);
SZT(work_struct,    struct work_struct);
SZT(pm_qos_request, struct pm_qos_request);
SZT(dev_pm_info,    struct dev_pm_info);

/* ── 第七处 ABI 的**核心偏移**：runtime ──
 *
 * 内核在 snd_pcm_attach_substream 里按**它的**偏移写 substream->runtime
 *     993:  substream->runtime = runtime;
 * 我们在 uac2_pcm_open 里按**我们的**偏移读
 *     364:  struct snd_pcm_runtime *runtime = substream->runtime;
 * 两边只要差 1 字节，读到的就是 kzalloc 的 0（真机 oops 的现场）。
 * 期望值：runtime = 312 = 136 + sizeof(pm_qos_request)=176
 *         （64 latency_pm_qos_req @64 → +176 = 240；buffer_bytes_max 248；
 *           dma_buffer 48 → 296；dma_max 304；ops 312 ⇒ runtime 312）
 */
SZO(snd_pcm_substream_runtime,            struct snd_pcm_substream, runtime);
SZO(snd_pcm_substream_latency_pm_qos_req, struct snd_pcm_substream, latency_pm_qos_req);
SZO(snd_pcm_substream_buffer_bytes_max,   struct snd_pcm_substream, buffer_bytes_max);
SZO(snd_pcm_substream_dma_buffer,         struct snd_pcm_substream, dma_buffer);
SZO(snd_pcm_substream_ops,                struct snd_pcm_substream, ops);
SZO(snd_pcm_substream_pid,                struct snd_pcm_substream, pid);
SZO(snd_pcm_substream_proc_root,          struct snd_pcm_substream, proc_root);

/* ── 第五处 ABI 的锚点：struct device 的四个成员 ──
 *
 * 设备内核 device_add() 自己的机器码实测（x19 = dev）：type=88 / class=752 /
 * groups=760 / release=768。当年就是因为 class/groups/release 偏了 8，
 * 才引出"厂商私有 +8"的误判。现在占位补丁已删，改用配置（TIMER_STATS=y /
 * MSI=n）自然得到同样的值 —— 这四条断言就是"删占位之后没有回退"的回归网。 */
SZO(device_type,    struct device, type);
SZO(device_class,   struct device, class);
SZO(device_groups,  struct device, groups);
SZO(device_release, struct device, release);
#ifdef CONFIG_PM
/* dev_pm_info.suspend_timer 就是 TIMER_STATS 通过 struct device 影响布局的那一处。 */
SZO(dev_pm_info_suspend_timer, struct dev_pm_info, suspend_timer);
SZO(dev_pm_info_work,          struct dev_pm_info, work);
#endif

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
