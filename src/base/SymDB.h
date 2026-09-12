// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include "common/service/Logger.h"
#include "common/service/Singleton.h"

#include <QHash>
#include <QSet>
#include <QString>

namespace mod {

class SymDB : public Singleton<SymDB>, private Logger {
public:
    size_t count();

    void* query(const std::string& name);

private:
    friend Singleton<SymDB>;
    explicit SymDB();

    uint64 _getImageBase(const std::string& module);

    QHash<QString, uint64> mDatabase;
    QSet<QString>          mMissing; // 查不到的符号记在这里，避免重复解析和刷屏
};

} // namespace mod
