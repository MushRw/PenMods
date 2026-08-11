// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

namespace mod {

// 确保外部播放器（/userdisk/mpv）已安装：
// 缺失时从 /userdata/PenMods/player.zip 解压部署，并修正 /userdisk/VideoPlayer 软链。
void ensurePlayerInstalled();

} // namespace mod
