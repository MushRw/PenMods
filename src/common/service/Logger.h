// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#pragma once

#include <atomic>

// 本头文件直接依赖 spdlog 的类型（spdlog::logger / sink_ptr / sinks::stdout_color_sink_mt），
// 之前是靠包含顺序偶然编过的。显式引入，避免 Hook.h 之类只经 SymDB.h 间接包含它时炸掉。
#include <spdlog/sinks/stdout_color_sinks.h>
#include <spdlog/spdlog.h>

namespace mod {

class Logger : public spdlog::logger {
public:
    Logger(const Logger&)            = delete;
    Logger& operator=(const Logger&) = delete;

    Logger(const Logger&&)             = delete;
    Logger&& operator=(const Logger&&) = delete;

    // Config 构造完成后设为 true，此后新创建的 Logger 会从 Config 读取级别
    static std::atomic<bool> s_configLoaded;

protected:
    explicit Logger(const std::string& name) : logger(name) {
        sinks().emplace_back(_getLoggingSink());
        // %^ 和 %$ 标记颜色范围：stdout_color_sink_mt 内置默认颜色
        //   trace=白色, debug=青色, info=绿色, warn=黄色, err=红色, critical=红底白字加粗
        set_pattern("[%H:%M:%S.%e] [%n] [%^%l%$] %^%v%$");

        // 从 Config 读取当前模块的日志级别（实现在 Logger.cpp）
        _applyLevelFromConfig(name);
    }

private:
    static spdlog::sink_ptr _getLoggingSink() {
        static spdlog::sink_ptr sink = nullptr;
        if (!sink) {
            sink = std::make_shared<spdlog::sinks::stdout_color_sink_mt>();
        }
        return sink;
    }

    void _applyLevelFromConfig(const std::string& name);
};

} // namespace mod
