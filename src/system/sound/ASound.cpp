// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "ASound.h"

#include "common/Utils.h"
#include "common/util/System.h"

namespace mod {

ASound::ASound() : Logger("ASound") {

    // 这里不再连 Event::uiCompleted。
    // AntiEmbs::onUiCompleted 在同一信号上会 emit lowVoiceModeChanged() → setDb()，
    // 而 ASound 只是再写一遍刚被写过、内容完全相同的同一个文件：开机 3 次多余 popen
    // （get_pcba_version + remount rw + remount ro）、2 次多余的 flash 截断写、
    // 1 轮多余的 rootfs remount，纯冗余（SD-05）。
}

bool ASound::setDb(VoiceDb val) {
    mVoiceDb = val;
    return _resetConfig();
}

ASound::VoiceDb ASound::getDb() { return mVoiceDb; }

bool ASound::_resetConfig() {
    auto cfg = _getConfig();
    // 机型不在匹配表里（现网会有 Dictpen2.0_V0 与 unkown_V?）：**宁可不写，也不能用自写的
    // "default" 覆盖厂商的 asound.conf**。那份自写内容只有厂商版的 0.38 相似度，会把
    // capture.pcm 从 hw:0,1 改成 plug/hw:0,0（录音采集链路）、playback.pcm 从 plug_ply
    // 改成 rk_eqdrc，并丢掉 pcm.dmixer / 2mic / ana_phone / softvol_cap / fake_jack* 等
    // 14 个块；更糟的是 /etc/asound.conf 是 /userdata/cfg/asound.conf 的 bind mount，
    // 改动会穿透到可写分区、重启也回不去（SD-01）。
    if (cfg.mPath.empty() || cfg.mContent.empty()) {
        warn("No asound configuration matched this device, keep the vendor one untouched.");
        return false;
    }
    auto content = QString::fromStdString(cfg.mContent)
                       .replace("{mindb}", QString::number(mVoiceDb.min, 'f', 1))
                       .replace("{maxdb}", QString::number(mVoiceDb.max, 'f', 1))
                       .toStdString();
    // cfg.mPath 是 rootfs 上的 /etc/asound.conf.<model>：只在真正写文件的这段
    // 时间把 / 临时放开为可写，写完还原（原来是开机就整段会话保持 rw）。
    const bool wasWritable = util::isRootFileSystemWritable();
    if (!util::setRootFileSystemWritable(true)) {
        error("Failed to remount / writable, abort writing asound configuration.");
        return false;
    }

    bool ok = true;
    {
        std::ofstream ofile(cfg.mPath);
        if (!ofile.good()) {
            error("Failed to open {} for writing.", cfg.mPath);
            ok = false;
        } else {
            ofile << content;
            ofile.close();
        }
    }
    if (ok) {
        // /etc/asound.conf 是指向 /userdata/cfg/asound.conf 的 bind mount，本身可写；
        // 与厂商自己的做法一致，两个文件写同一份内容。
        std::ofstream ofile("/etc/asound.conf");
        if (!ofile.good()) {
            error("Failed to open /etc/asound.conf for writing.");
            ok = false;
        } else {
            ofile << content;
            ofile.close();
        }
    }

    // 无论写入成败都必须把 / 还原。归还失败 = rootfs 停在 rw（本设备唯一"改不坏"的保险
    // 失效），这里必须让调用方看得见，不能像以前那样丢弃返回值然后 return true（SD-03）。
    if (!util::setRootFileSystemWritable(wasWritable)) {
        error("Failed to restore rootfs mount state (wasWritable={}). / may be left writable!", wasWritable);
        return false;
    }
    return ok;
}

std::string ASound::_getRawConfigure(const char* model) {
    switch (H(model)) {
    case H("V4"):
        return R"(defaults.pcm.rate_converter "speexrate_medium"
pcm.!default
{
    type asym
    playback.pcm "plug_ply" # no use ladspa path for eq_drc_process
    capture.pcm "plug:dsnooper"
}

# start for soft playback >>>
pcm.plug_ply {
    type plug
    slave.pcm "softvol_ply"
}

pcm.dsnooper {
    type dsnoop
    ipc_key 12342 # must be unique for all dmix plugins!!!!
    ipc_key_add_uid true
    slave {
        pcm "hw:0,0"
        channels 2
        rate 48000
    }
    bindings {
        0 0
        1 1
    }
}
pcm.dmixer {
    type dmix
    ipc_key 5978293 # must be unique for all dmix plugins!!!!
    ipc_key_add_uid yes
    slave {
        pcm "hw:7,0,0"
        channels 2
        period_size 1024
        buffer_size 4096
    }
    bindings {
        0 0
        1 1
    }
}

pcm.softvol_ply {
    type softvol
    # slave.pcm "hooks_ply" # no use eq_drc_process
    # slave.pcm "hw:7,0,0" # using eq_drc_process for loopback
    # slave.pcm "rk_eqdrc" # using eq_drc_process for loopback
    slave.pcm "dmixer" # using eq_drc_process for loopback
    control {
        name "MasterP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}
# end for soft playback <<<

# start for spk playpath >>>
pcm.playback {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "SPK"
            lock false
        }]
    }
}

pcm.rk_eqdrc {
    type plug
    slave {
        pcm {
            type softvol
            slave.pcm "plug:ladspa_play"
            control {
                name "Master Playback Volume"
                card 0
            }
            min_dB {mindb}
            max_dB {maxdb}
            resolution 256
        }
        channels 2
        format S16_LE
        rate 48000
    }
}

pcm.ladspa_play {
    type ladspa
    # slave.pcm "hw:0,0"
    slave.pcm "plug:playback"
    path "/usr/share/alsa/"
    playback_plugins [{
        label eq_drc_stereo
            input {
                controls [0]
            }
    }]
}

pcm.ladspa_plug {
    type plug
    slave {
        pcm "ladspa_play"
    }
}
# end for spk playpath <<<

# start fot soft capture >>>
pcm.softvol_cap {
    type softvol
    slave.pcm "hw:0,1"
}
# end for soft capture <<<

# start for fake record >>>
pcm.fake_record {
    type plug
    slave.pcm "hw:7,1,0"
}
# end for fake record <<<

# start for fake playpath >>>
pcm.fake_play {
    type plug
    slave.pcm "rk_eqdrc" # with ladspa path for eq_drc_process
}
# end for fake playpath <<<

# start for digital headset:fake_jack >>>
pcm.fake_jack {
    type plug
    slave.pcm "dig_hp"
}
pcm.dig_hp {
    type plug
    slave.pcm "hw:1,0"
}
# end for digital headset <<<

# for ana headset:fake_jack2 >>>
pcm.fake_jack2 {
    type plug
    slave.pcm "ana_phone"
}

pcm.hooks_ana_phone {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "HP"
            lock false
        }]
    }
}

pcm.softvol_ana_phone {
    type softvol
    slave.pcm "hooks_ana_phone"
    control {
        name "MasterAHP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}

pcm.ana_phone
{
    type plug
    slave {
        pcm "softvol_ana_phone"
        rate 48000
    }
}
# end for ana headset <<<

pcm.multi_2 {
    type multi
    slaves.a.pcm "hw:0,1"
    slaves.a.channels 4
    bindings.0.slave a
    bindings.0.channel 2
    bindings.1.slave a
    bindings.1.channel 3
}

pcm.2mic
{
    type plug
    slave.pcm "multi_2"
}
)";
    case H("Mango6L"):
        return R"(defaults.pcm.rate_converter "speexrate_medium"
pcm.!default
{
    type asym
    playback.pcm "plug_ply" # no use ladspa path for eq_drc_process
    capture.pcm "hw:0,0"
}

# start for soft playback >>>
pcm.plug_ply {
    type plug
    slave.pcm "softvol_ply"
}

pcm.dmixer {
    type dmix
    ipc_key 5978293 # must be unique for all dmix plugins!!!!
    ipc_key_add_uid yes
    slave {
        pcm "hw:7,0,0"
        channels 2
        period_size 1024
        buffer_size 4096
    }
    bindings {
        0 0
        1 1
    }
}

pcm.softvol_ply {
    type softvol
    # slave.pcm "hooks_ply" # no use eq_drc_process
    # slave.pcm "hw:7,0,0" # using eq_drc_process for loopback
    # slave.pcm "rk_eqdrc" # using eq_drc_process for loopback
    slave.pcm "dmixer" # using eq_drc_process for loopback
    control {
        name "MasterP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}
# end for soft playback <<<

# start for spk playpath >>>
pcm.playback {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "SPK"
            lock false
        }]
    }
}

pcm.rk_eqdrc {
    type plug
    slave {
        pcm {
            type softvol
            slave.pcm "plug:ladspa_play"
            control {
                name "Master Playback Volume"
                card 0
            }
            min_dB {mindb}
            max_dB {maxdb}
            resolution 256
        }
        channels 2
        format S16_LE
        rate 48000
    }
}

pcm.ladspa_play {
    type ladspa
    # slave.pcm "hw:0,0"
    slave.pcm "plug:playback"
    path "/usr/share/alsa/"
    playback_plugins [{
        label eq_drc_stereo
            input {
                controls [0]
            }
    }]
}

pcm.ladspa_plug {
    type plug
    slave {
        pcm "ladspa_play"
    }
}
# end for spk playpath <<<

# start fot soft capture >>>
pcm.softvol_cap {
    type softvol
    slave.pcm "hw:0,1"
}
# end for soft capture <<<

# start for fake record >>>
pcm.fake_record {
    type plug
    slave.pcm "hw:7,1,0"
}
# end for fake record <<<

# start for fake playpath >>>
pcm.fake_play {
    type plug
    slave.pcm "rk_eqdrc" # with ladspa path for eq_drc_process
}
# end for fake playpath <<<

# start for digital headset:fake_jack >>>
pcm.fake_jack {
    type plug
    slave.pcm "dig_hp"
}
pcm.dig_hp {
    type plug
    slave.pcm "hw:1,0"
}
# end for digital headset <<<

# for ana headset:fake_jack2 >>>
pcm.fake_jack2 {
    type plug
    slave.pcm "ana_phone"
}

pcm.hooks_ana_phone {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "HP"
            lock false
        }]
    }
}

pcm.softvol_ana_phone {
    type softvol
    slave.pcm "hooks_ana_phone"
    control {
        name "MasterAHP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}

pcm.ana_phone
{
    type plug
    slave {
        pcm "softvol_ana_phone"
        rate 48000
    }
}
# end for ana headset <<<

pcm.multi_2 {
    type multi
    slaves.a.pcm "hw:0,1"
    slaves.a.channels 4
    bindings.0.slave a
    bindings.0.channel 2
    bindings.1.slave a
    bindings.1.channel 3
}

pcm.2mic
{
    type plug
    slave.pcm "multi_2"
}
)";

    case H("Exam"):
        return R"(defaults.pcm.rate_converter "speexrate_medium"
pcm.!default
{
    type asym
    playback.pcm "plug_ply" # no use ladspa path for eq_drc_process
    capture.pcm "plug:dsnooper"
}

# start for soft playback >>>
pcm.plug_ply {
    type plug
    slave.pcm "softvol_ply"
}

pcm.dsnooper {
    type dsnoop
    ipc_key 12342 # must be unique for all dmix plugins!!!!
    ipc_key_add_uid true
    slave {
        pcm "hw:0,0"
        channels 2
        rate 48000
    }
    bindings {
        0 0
        1 1
    }
}
pcm.dmixer {
    type dmix
    ipc_key 5978293 # must be unique for all dmix plugins!!!!
    ipc_key_add_uid yes
    slave {
        pcm "hw:7,0,0"
        channels 2
        period_size 1024
        buffer_size 4096
    }
    bindings {
        0 0
        1 1
    }
}

pcm.softvol_ply {
    type softvol
    # slave.pcm "hooks_ply" # no use eq_drc_process
    # slave.pcm "hw:7,0,0" # using eq_drc_process for loopback
    # slave.pcm "rk_eqdrc" # using eq_drc_process for loopback
    slave.pcm "dmixer" # using eq_drc_process for loopback
    control {
        name "MasterP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}
# end for soft playback <<<

# start for spk playpath >>>
pcm.playback {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "SPK"
            lock false
        }]
    }
}

pcm.rk_eqdrc {
    type plug
    slave {
        pcm {
            type softvol
            slave.pcm "plug:ladspa_play"
            control {
                name "Master Playback Volume"
                card 0
            }
            min_dB {mindb}
            max_dB {maxdb}
            resolution 256
        }
        channels 2
        format S16_LE
        rate 48000
    }
}

pcm.ladspa_play {
    type ladspa
    # slave.pcm "hw:0,0"
    slave.pcm "plug:playback"
    path "/usr/share/alsa/"
    playback_plugins [{
        label eq_drc_stereo
            input {
                controls [0]
            }
    }]
}

pcm.ladspa_plug {
    type plug
    slave {
        pcm "ladspa_play"
    }
}
# end for spk playpath <<<

# start fot soft capture >>>
pcm.softvol_cap {
    type softvol
    slave.pcm "hw:0,1"
}
# end for soft capture <<<

# start for fake record >>>
pcm.fake_record {
    type plug
    slave.pcm "hw:7,1,0"
}
# end for fake record <<<

# start for fake playpath >>>
pcm.fake_play {
    type plug
    slave.pcm "rk_eqdrc" # with ladspa path for eq_drc_process
}
# end for fake playpath <<<

# start for digital headset:fake_jack >>>
pcm.fake_jack {
    type plug
    slave.pcm "dig_hp"
}
pcm.dig_hp {
    type plug
    slave.pcm "hw:1,0"
}
# end for digital headset <<<

# for ana headset:fake_jack2 >>>
pcm.fake_jack2 {
    type plug
    slave.pcm "ana_phone"
}

pcm.hooks_ana_phone {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "HP"
            lock false
        }]
    }
}

pcm.softvol_ana_phone {
    type softvol
    slave.pcm "hooks_ana_phone"
    control {
        name "MasterAHP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}

pcm.ana_phone
{
    type plug
    slave {
        pcm "softvol_ana_phone"
        rate 48000
    }
}
# end for ana headset <<<

pcm.multi_2 {
    type multi
    slaves.a.pcm "hw:0,1"
    slaves.a.channels 4
    bindings.0.slave a
    bindings.0.channel 2
    bindings.1.slave a
    bindings.1.channel 3
}

pcm.2mic
{
    type plug
    slave.pcm "multi_2"
}
)";

    case H("Cherry"):
        return R"(defaults.pcm.rate_converter "speexrate_medium"
pcm.!default
{
    type asym
    playback.pcm "plug_ply" # no use ladspa path for eq_drc_process
    capture.pcm "hw:0,1"
}

# start for soft playback >>>
pcm.plug_ply {
    type plug
    slave.pcm "softvol_ply"
}

pcm.dmixer {
    type dmix
    ipc_key 5978293 # must be unique for all dmix plugins!!!!
    ipc_key_add_uid yes
    slave {
        pcm "hw:7,0,0"
        channels 2
        period_size 1024
        buffer_size 4096
    }
    bindings {
        0 0
        1 1
    }
}

pcm.softvol_ply {
    type softvol
    # slave.pcm "hooks_ply" # no use eq_drc_process
    # slave.pcm "hw:7,0,0" # using eq_drc_process for loopback
    # slave.pcm "rk_eqdrc" # using eq_drc_process for loopback
    slave.pcm "dmixer" # using eq_drc_process for loopback
    control {
        name "MasterP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}
# end for soft playback <<<

# start for spk playpath >>>
pcm.playback {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "SPK"
            lock false
        }]
    }
}

pcm.rk_eqdrc {
    type plug
    slave {
        pcm {
            type softvol
            slave.pcm "plug:ladspa_play"
            control {
                name "Master Playback Volume"
                card 0
            }
            min_dB {mindb}
            max_dB {maxdb}
            resolution 256
        }
        channels 2
        format S16_LE
        rate 48000
    }
}

pcm.ladspa_play {
    type ladspa
    # slave.pcm "hw:0,0"
    slave.pcm "plug:playback"
    path "/usr/share/alsa/"
    playback_plugins [{
        label eq_drc_stereo
            input {
                controls [0]
            }
    }]
}

pcm.ladspa_plug {
    type plug
    slave {
        pcm "ladspa_play"
    }
}
# end for spk playpath <<<

# start fot soft capture >>>
pcm.softvol_cap {
    type softvol
    slave.pcm "hw:0,1"
}
# end for soft capture <<<

# start for fake record >>>
pcm.fake_record {
    type plug
    slave.pcm "hw:7,1,0"
}
# end for fake record <<<

# start for fake playpath >>>
pcm.fake_play {
    type plug
    slave.pcm "rk_eqdrc" # with ladspa path for eq_drc_process
}
# end for fake playpath <<<

# start for digital headset:fake_jack >>>
pcm.fake_jack {
    type plug
    slave.pcm "dig_hp"
}
pcm.dig_hp {
    type plug
    slave.pcm "hw:1,0"
}
# end for digital headset <<<

# for ana headset:fake_jack2 >>>
pcm.fake_jack2 {
    type plug
    slave.pcm "ana_phone"
}

pcm.hooks_ana_phone {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "HP"
            lock false
        }]
    }
}

pcm.softvol_ana_phone {
    type softvol
    slave.pcm "hooks_ana_phone"
    control {
        name "MasterAHP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}

pcm.ana_phone
{
    type plug
    slave {
        pcm "softvol_ana_phone"
        rate 48000
    }
}
# end for ana headset <<<

pcm.multi_2 {
    type multi
    slaves.a.pcm "hw:0,1"
    slaves.a.channels 4
    bindings.0.slave a
    bindings.0.channel 2
    bindings.1.slave a
    bindings.1.channel 3
}

pcm.2mic
{
    type plug
    slave.pcm "multi_2"
}
)";

    case H("Cherry_3566"):
        return R"(defaults.pcm.rate_converter "speexrate_medium"
pcm.!default
{
    type asym
    playback.pcm "plug_ply" # no use ladspa path for eq_drc_process
    capture.pcm "hw:0,1"
}

# start for soft playback >>>
pcm.plug_ply {
    type plug
    slave.pcm "softvol_ply"
}

pcm.dmixer {
    type dmix
    ipc_key 5978293 # must be unique for all dmix plugins!!!!
    ipc_key_add_uid yes
    slave {
        pcm "hw:7,0,0"
        channels 2
        period_size 1024
        buffer_size 4096
    }
    bindings {
        0 0
        1 1
    }
}

pcm.softvol_ply {
    type softvol
    # slave.pcm "hooks_ply" # no use eq_drc_process
    # slave.pcm "hw:7,0,0" # using eq_drc_process for loopback
    # slave.pcm "rk_eqdrc" # using eq_drc_process for loopback
    slave.pcm "dmixer" # using eq_drc_process for loopback
    control {
        name "MasterP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}
# end for soft playback <<<

# start for spk playpath >>>
pcm.playback {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "SPK"
            lock false
        }]
    }
}

pcm.rk_eqdrc {
    type plug
    slave {
        pcm {
            type softvol
            slave.pcm "plug:ladspa_play"
            control {
                name "Master Playback Volume"
                card 0
            }
            min_dB {mindb}
            max_dB {maxdb}
            resolution 256
        }
        channels 2
        format S16_LE
        rate 48000
    }
}

pcm.ladspa_play {
    type ladspa
    # slave.pcm "hw:0,0"
    slave.pcm "plug:playback"
    path "/usr/share/alsa/"
    playback_plugins [{
        label eq_drc_stereo
            input {
                controls [0]
            }
    }]
}

pcm.ladspa_plug {
    type plug
    slave {
        pcm "ladspa_play"
    }
}
# end for spk playpath <<<

# start fot soft capture >>>
pcm.softvol_cap {
    type softvol
    slave.pcm "hw:0,1"
}
# end for soft capture <<<

# start for fake record >>>
pcm.fake_record {
    type plug
    slave.pcm "hw:7,1,0"
}
# end for fake record <<<

# start for fake playpath >>>
pcm.fake_play {
    type plug
    slave.pcm "rk_eqdrc" # with ladspa path for eq_drc_process
}
# end for fake playpath <<<

# start for digital headset:fake_jack >>>
pcm.fake_jack {
    type plug
    slave.pcm "dig_hp"
}
pcm.dig_hp {
    type plug
    slave.pcm "hw:1,0"
}
# end for digital headset <<<

# for ana headset:fake_jack2 >>>
pcm.fake_jack2 {
    type plug
    slave.pcm "ana_phone"
}

pcm.hooks_ana_phone {
    type hooks
    slave.pcm "hw:0,0"
    hooks.0 {
        type ctl_elems
        hook_args [{
            name "Playback Path"
            preserve true
            value "HP"
            lock false
        }]
    }
}

pcm.softvol_ana_phone {
    type softvol
    slave.pcm "hooks_ana_phone"
    control {
        name "MasterAHP Volume"
        card 0
        device 0
    }
    min_dB {mindb}
    max_dB {maxdb}
    resolution 100
}

pcm.ana_phone
{
    type plug
    slave {
        pcm "softvol_ana_phone"
        rate 48000
    }
}
# end for ana headset <<<

pcm.multi_2 {
    type multi
    slaves.a.pcm "hw:0,1"
    slaves.a.channels 4
    bindings.0.slave a
    bindings.0.channel 2
    bindings.1.slave a
    bindings.1.channel 3
}

pcm.2mic
{
    type plug
    slave.pcm "multi_2"
})";
    default:
        // 以前这里返回一份自写的 75 行 "default" 配置，用来覆盖"型号不在匹配表"的
        // 设备（现网确实存在 Dictpen2.0_V0 与 unkown_V?）。那份内容与厂商版相似度只有
        // 0.38，会把 capture.pcm 从 hw:0,1 改成 plug/hw:0,0（录音采集链路）、
        // playback.pcm 从 plug_ply 改成 rk_eqdrc，并丢掉 pcm.dmixer / 2mic /
        // ana_phone / softvol_cap / fake_jack* 等 14 个块；而 /etc/asound.conf 是
        // /userdata/cfg/asound.conf 的 bind mount，改动会穿透到可写分区且重启回不去。
        // 已改为"宁可不写，也不覆盖厂商文件"（SD-01）。
        warn("No built-in asound configuration for model '{}'.", model);
        return "";
    }
}

ASound::Config ASound::_getConfig() {
    auto pcba = exec("get_pcba_version");
    if (pcba == "Dictpen2.0_V4") {
        return {"/etc/asound.conf.V4", _getRawConfigure("V4")};
    }
    if (pcba == "Cherry_V0" || pcba == "Mango_V0" || pcba == "Kiwi-3326_V0") {
        return {"/etc/asound.conf.VCherry", _getRawConfigure("Cherry")};
    }
    if (pcba == "Mango_V1") {
        return {"/etc/asound.conf.VMango6L", _getRawConfigure("Mango6L")};
    }
    if (pcba == "Cherry-3566_V0" || pcba == "Kiwi-3566_V0") {
        return {"/etc/asound.conf.VCherry_3566", _getRawConfigure("Cherry_3566")};
        //} else if (pcba == "Apollo_V0") {
        //    return {"/etc/asound.conf.VApollo",asound_Apollo};
    }
    if (pcba == "Exam_V0") {
        return {"/etc/asound.conf.VExam", _getRawConfigure("Exam")};
    }
    warn("Unable to find a matching asound configuration file for this pcba({}).", pcba);
    // 返回空表示"没有匹配的配置"：调用方据此放弃写入，保留厂商原文件（SD-01）。
    // 这里以前返回 {"/etc/asound.conf", _getRawConfigure("default")}，等于用 75 行的
    // 自写内容整体覆盖厂商 176 行 / 21 个定义块的文件。
    return {"", ""};
}

} // namespace mod
