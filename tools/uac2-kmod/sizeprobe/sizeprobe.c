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

#define SZT(n, t) char penmods_sz_##n[sizeof(t)] __attribute__((used))

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
