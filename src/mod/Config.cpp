// SPDX-License-Identifier: GPL-3.0-only
/*
 * Copyright (C) 2022-present, PenUniverse.
 * This file is part of the PenMods open source project.
 */

#include "mod/Config.h"

#include "common/Utils.h"

#include "common/util/System.h"

#include "Version.h"

#include <fstream>
#include <set>

namespace fs = std::filesystem;

namespace mod {

std::string get_config_path() { return (util::getModuleFileInfo().absolutePath() + "/config.json").toStdString(); }

Config::Config() : Logger("Config") {

    // clang-format off

    mData = {
        {"version", VERSION_CONFIG},
        {"column_db", {
             {"patch", true}
        }},
        {"dev", {
            {"offline_rm", true}
        }},
        {"net", {
            {"proxy_enabled", false},
            {"proxy_type", 0},
            {"proxy_hostname", "127.0.0.1"},
            {"proxy_port", 1270},
            {"proxy_username", ""},
            {"proxy_password", ""},
        }},
        {"logger", {
            {"no_upload_user_action", true},
            {"no_upload_raw_scan_img", true},
            {"no_upload_httplog", true},
            {"filtered_tags", {
                "queue", "sender",
                "YDownloader", "YColumnDb", "YHttpManager",
                "YHistoryManager", "YWordBookManager", "YNetTranslateEngine",
                "YColumnManager", "YMediaManager", "YMediaPlayerManager",
                "YTextBookDb", "YTextBookManager", "YTextBookBlockManager",
                "YTextBookTaskManager", "YStrokeManager", "YInteractiveLearningManager",
                "YReadingBookQuestionOptionManager",
                "YLoginManager", "BlueToothManager",
                "YRecordCenter", "YSystemBase", "YLogManager"
            }},
            {"levels", {
                {"Config", "debug"},
                {"MusicPlayer", "info"},
                {"FileManager", "info"},
                {"TextBook", "info"},
                {"ChatBot", "info"},
                {"Hitokoto", "info"},
                {"RimeWrapper", "info"},
                {"Rime", "info"},
                {"AudioDaemon", "info"},
                {"InputDaemon", "info"},
                {"AudioRecorder", "info"},
                {"SymDB", "info"},
                {"ImageViewer", "info"},
                {"WebPImageProvider", "info"},
                {"WebPAnimatedImage", "info"},
                {"PluginManager", "info"},
                {"Updater", "info"},
                {"ASound", "info"}
            }}
        }},
        {"query", {
            {"lower_scan", false},
            {"type_by_hand", true}
        }},
        {"wordbook", {
            {"phrase_tab", true},
            {"nocase_sensitive", true}
        }},
        {"screen", {
            {"sleep_duration", 30},
            {"shutdown_duration", 0},
            {"intel_sleep", false},
            {"intel_sleep_audio_lock", false},
            // ScreenManager::setLockScreen() 会写这个键，而 ScreenManager.cpp 用
            // mCfg.value("lock_screen", true) 读 —— 漏在 mDefaults 里的话，
            // sanitize() 会把它当未知字段删掉，用户关掉的锁屏会在下次开机被改回 true。
            {"lock_screen", true}
        }},
        {"battery", {
            {"suspend_duration", 600},
            {"performance_mode", 0}
        }},
        {"locker", {
            {"enabled", false},
            {"password", "abcd"},
            {"scene", {
                {"screen_on", false},
                {"restart", true},
                {"reset_page", true},
                {"dev_setting", false},
                {"filemanager",false},
                {"antiembs_deactivate", false}
            }}
        }},
        {"antiembs", {
            {"auto_mute", false},
            {"low_voice", false},
            {"no_auto_pron", false},
            {"fast_hide_music", false},
            {"fast_mute", false}
        }},
        {"serv", {
            {"ssh_autorun", false},
            {"adb_autorun", false},
            {"adb_skip_verification", false}
        }},
        {"fm", {
            {"order", {
                {"basic", 0},
                {"reversed", false}
            }},
            {"hide_paired_lyrics", false},
            {"show_hidden_files", false},
            {"pause_on_scan", false},
            {"hide_floating_window", false}
        }},
        {"wallpaper", {
            {"mode", 0},
            {"custom_image_path", ""},
            {"wallpaper_folder", ""},
            {"cycle_interval", 300},
            {"last_wallpaper", ""}
        }},
        {"capture", {
            {"enabled", false}
        }},
        {"theme", {
            {"id", "official"},
            // ThemeManager::_save() 会写 surfaceStyle（opaque / translucent / glass），
            // 默认值必须与 ThemeManager::_load() 的 cfg.value("surfaceStyle", ...) 一致。
            // 漏在 mDefaults 里 = 用户的表面风格每次开机被静默重置（AP-10）。
            {"surfaceStyle", "translucent"}
        }},
        {"ai", {
            {"auto_send_scan", true},
            {"speech_assistant", false},
            {"streaming", true},
            {"bubble_render_mode", "full"},
            {"models", json::array({
                json{
                    {"id",          "deepseek-v4-flash"},
                    {"name",        "DeepSeek Chat"},
                    {"provider",    "DeepSeek"},
                    {"endpoint",    "https://api.deepseek.com/v1/chat/completions"},
                    {"modelId",     "deepseek-v4-flash"},
                    {"apiProtocol", "chat_completions"},
                    {"apiKey",      ""},
                    {"temperature", 0.7},
                    {"maxContextSize", 0},
                    {"reasoningEffort", ""},
                    {"nativeWebSearchEnabled", false},
                    {"nativeWebSearchProvider", "auto"},
                    {"capabilities", json{
                        {"text",      true},
                        {"vision",    false},
                        {"audio",     false},
                        {"toolCall",  false},
                        {"toolCall",  false},
                        {"reasoning",       false},
                        {"imageGeneration", false}
                    }},
                    {"extraParams", ""},
                    {"proxyVisionModelId", ""},
                    {"proxyVisionPrompt", "请详细描述这张图片的内容。如果图片中有文字，请完整转录。"}
                }
            })},
            {"activeModelId", "deepseek-v4-flash"},
            {"prompts", json::array({
                json{
                    {"id",      "default"},
                    {"name",    "通用助手"},
                    {"content", "你是一个有用的助手，使用中文回复用户的问题。"}
                }
            })},
            {"activePromptId", "default"},
            {"tavily", {
                {"api_key",      ""},
                {"search_depth", "advanced"},
                {"max_results",  5},
                {"enabled",      false}
            }},
            {"shell_tool", {
                {"enabled",   false},
                {"timeout_ms", 10000},
                {"max_output_bytes", 4096},
                {"blocklist", json::array()}
            }},
            {"math_render", {
                {"enabled",     false},
                {"server_path", ""}
            }}
        }}
    };

    // clang-format on

    mDefaults = mData;
    if (_load()) {
        // CF-1：_load() 只保证「文件能解析 + 版本已迁移」，不保证「字段合法」。
        // 历史上各功能类都是各自写防御式读取来兜住字段缺失/多余（`mCfg["x"]` 裸读，
        // 键不存在时 nlohmann 会插入 null，再转 bool/int 就抛 type_error），
        // 而它们全都在开机路径上构造 —— 一个缺键就能让启动崩，进而被厂商崩溃保护
        // 放大成 update_engine --misc=clear + 切槽。
        // 在入口统一净化一次，等价于给 15 个类 / 60 个读点一次性上保险。
        // 注意：mDefaults 就是白名单，任何新写的键都必须先补进 mDefaults（见 cfgkey_check.py）。
        sanitize();
    }

    // Config 初始化完成，后续 Logger 可以从 Config 读取日志级别
    Logger::s_configLoaded = true;
}

json Config::read(const std::string& name) {
    if (!mData.contains(name)) {
        // 返回空对象而不是 null：调用方普遍写成 cfg.value("x", default)，
        // 而 nlohmann 的 value() 对 null 会抛 type_error.306（只有 object 才安全）。
        // 段名写错 / 尚未补齐时会直接崩在读配置这一步，就是在开机路径上崩。
        return json::object();
    }
    return mData.at(name);
}

bool Config::write(const std::string& name, json content, bool saveImmediately) {
    if (mData.find(name) == mData.end()) {
        return false;
    }
    mData[name] = std::move(content);
    if (saveImmediately) {
        _save();
    }
    return true;
}

bool Config::_update(json& data) {
    if (!data.contains("version") || data.at("version") == VERSION_CONFIG) {
        return false;
    }
    info("Configuration file is being updated...");

    try {

        // v100 -> v110
        if (data["version"] < 110) {
            data["fm"] = {
                {"order", {{"basic", 0}, {"reversed", false}}}
            };
            data["antiembs"]["fast_mute"] = false;
            data["version"]               = 110;
        }

        // v110 -> v116
        if (data["version"] < 116) {
            data["locker"]["scene"]["dev_setting"] = false;
            data["version"]                        = 116;
        }

        // v116 -> v117
        if (data["version"] < 117) {
            data["fm"]["hide_paird_lyrics"]     = false;
            data["battery"]["performance_mode"] = 0;
            data["version"]                     = 117;
        }

        // v117 -> v118
        if (data["version"] < 118) {
            data["wordbook"].erase("mod_exporter");
            data["version"] = 118;
        }

        // v118 -> v120
        if (data["version"] < 120) {
            data["ai"] = {
                {"bing", {{"enabled", false}, {"request_address", ""}, {"chathub_address", ""}}}
            };
            data["version"] = 120;
        }

        // v120 -> v130
        if (data["version"] < 130) {
            data["ai"]["speech_assistant"]   = false;
            data["fm"]["hide_paired_lyrics"] = data["fm"]["hide_paird_lyrics"];
            data["fm"].erase("hide_paird_lyrics");
            data["dev"].erase("wifi_page_show_ip");
            data["column_db"].erase("limit");
            data["column_db"]["patch"] = true;
            data["version"]            = 130;
        }

        // v130 -> v131
        if (data["version"] < 131) {
            if (data.contains("ai")) {
                if (!data["ai"].contains("models") || !data["ai"]["models"].is_array()) {
                    auto& cb                    = data["ai"]["chatbot"];
                    data["ai"]["models"]        = json::array({
                        json{
                             {"id", cb.value("model", "deepseek-chat")},
                             {"name", "DeepSeek Chat"},
                             {"provider", "DeepSeek"},
                             {"endpoint", cb.value("api_endpoint", "https://api.deepseek.com/v1/chat/completions")},
                             {"modelId", cb.value("model", "deepseek-chat")},
                             {"apiProtocol", "chat_completions"},
                             {"apiKey", cb.value("api_key", "")},
                             {"temperature", cb.value("temperature", 0.7)},
                             {"reasoningEffort", ""},
                             {"extraParams", ""}
                        }
                    });
                    data["ai"]["activeModelId"] = cb.value("model", "deepseek-chat");
                }
                if (!data["ai"].contains("prompts") || !data["ai"]["prompts"].is_array()) {
                    std::string defPrompt = "你是一个有用的助手，使用中文回复用户的问题。";
                    if (data["ai"].contains("chatbot"))
                        defPrompt = data["ai"]["chatbot"].value("default_prompt", defPrompt);
                    data["ai"]["prompts"]        = json::array({
                        json{{"id", "default"}, {"name", "通用助手"}, {"content", defPrompt}}
                    });
                    data["ai"]["activePromptId"] = "default";
                }
                // 迁移 streaming 到顶层
                if (!data["ai"].contains("streaming") && data["ai"].contains("chatbot"))
                    data["ai"]["streaming"] = data["ai"]["chatbot"].value("streaming", true);
            }
            data["version"] = 131;
        }

    } catch (...) {
        return false;
    }

    return true;
}

bool Config::_load() {
    info("Loading configuration...");
    auto path = get_config_path();
    if (!fs::exists(path)) {
        warn("Configuration not found, creating...");
        return _save() ? _load() : false;
    }
    json tmp;
    try {
        tmp = json::parse(readFile(path.c_str()));
    } catch (...) {}
    if (tmp.empty() || !tmp.contains("version")) {
        warn("Configuration error, being repaired...");
        return _save() ? _load() : false;
    }
    if (tmp["version"] != VERSION_CONFIG) {
        if (!_update(tmp)) {
            return false;
        }
        info("Saving configuration...");
    }
    mData = std::move(tmp);
    if (_fill_missing_defaults(mData, mDefaults)) {
        info("Filling missing default keys, saving...");
        _save();
    }
    info("Successfully loaded configuration.");
    return true;
}

bool Config::_save() {
    const auto path = get_config_path();
    const auto tmp  = path + ".tmp";
    {
        // 先写临时文件再原子改名：设备随时可能掉电，直接覆盖 config.json 会留下
        // 截断的文件，而 _load() 遇到损坏会重建默认配置 —— API Key 和全部设置就没了。
        std::ofstream ofile(tmp, std::ios::out | std::ios::trunc);
        if (!ofile.good()) {
            return false;
        }
        ofile << mData.dump(4);
        ofile.flush();
        if (!ofile.good()) {
            return false;
        }
    }
    std::error_code ec;
    fs::rename(tmp, path, ec);
    if (ec) {
        warn("配置写入失败: {}", ec.message());
        fs::remove(tmp, ec);
        return false;
    }
    return true;
}

// 递归补充 target 中缺失的默认键，保留 target 中已有的值和多余的键
bool Config::_fill_missing_defaults(json& target, const json& defaults) {
    bool changed = false;
    for (auto it = defaults.begin(); it != defaults.end(); ++it) {
        const auto& key = it.key();
        if (!target.contains(key)) {
            target[key] = it.value();
            changed     = true;
        } else if (it->is_object() && target[key].is_object()) {
            if (_fill_missing_defaults(target[key], *it)) {
                changed = true;
            }
        }
    }
    return changed;
}

// 递归删除 target 中不在 reference（mDefaults）里的字段，返回是否真的删了东西
bool Config::_strip_unknown_keys(json& target, const json& reference) {
    if (!target.is_object() || !reference.is_object()) return false;
    bool                     changed = false;
    std::vector<std::string> to_remove;
    for (auto it = target.begin(); it != target.end(); ++it) {
        if (!reference.contains(it.key())) {
            to_remove.push_back(it.key());
        } else if (it->is_object() && reference[it.key()].is_object()) {
            if (_strip_unknown_keys(*it, reference[it.key()])) changed = true;
        }
    }
    for (const auto& key : to_remove) {
        info("清洗配置：移除未知字段 '{}'", key);
        target.erase(key);
        changed = true;
    }
    return changed;
}

// 把"类型与默认值不符"的字段恢复成默认值。
//
// _fill_missing_defaults 只补缺失的 key，**不修错误的类型** —— 而 15 个功能类读配置用的是
// `mCfg["k"]` + nlohmann 的隐式类型转换，类型不对就抛 type_error：
// 例如用户手改 config.json 写成 {"locker": {"enabled": "yes"}}，`mCfg["enabled"]` 转 bool
// 即抛，而 Locker 是在开机路径上构造的 → 启动崩 → 厂商崩溃保护放大成切槽（CF-01）。
//
// 判据按"类型大类"比较：整数 / 无符号 / 浮点一律视为同类（nlohmann 之间可 static_cast，
// 例如 battery.suspend_duration 的默认值是 int 600 而写入侧是 uint32）；而 string / bool /
// object / array / null 必须严格一致。
// 已逐一核对全部 72 个写点：没有任何 setter 会往 bool 键写非 bool、或往 number 键写非数字。
bool Config::_repair_types(json& target, const json& defaults) {
    if (!target.is_object() || !defaults.is_object()) return false;
    static const auto jsonKind = [](const json& v) -> char {
        if (v.is_object()) return 'o';
        if (v.is_array()) return 'a';
        if (v.is_string()) return 's';
        if (v.is_boolean()) return 'b';
        if (v.is_number()) return 'n';
        return '?'; // null / binary / discarded
    };
    bool changed = false;
    for (auto it = defaults.begin(); it != defaults.end(); ++it) {
        const auto& key = it.key();
        if (!target.contains(key)) continue; // 缺失的键由 _fill_missing_defaults 负责
        // 用 at() 而不是 operator[]：后者在键缺失时会插入 null（这里已判过 contains，
        // 但读操作不该有写语义）。
        const char want = jsonKind(*it);
        const char have = jsonKind(target.at(key));
        if (want == 'o' && have == 'o') {
            if (_repair_types(target.at(key), *it)) changed = true;
        } else if (want != have) {
            warn("配置修复：字段 '{}' 类型不符（默认 {} / 当前 {}），已恢复为默认值", key, want, have);
            target[key] = *it;
            changed = true;
        }
    }
    return changed;
}

bool Config::sanitize() {
    bool changed = _strip_unknown_keys(mData, mDefaults);
    if (_fill_missing_defaults(mData, mDefaults)) changed = true;
    if (_repair_types(mData, mDefaults)) changed = true;
    if (!changed) {
        // 没有变化就不写盘：sanitize() 现在每次开机都会跑，无条件 _save()
        // 等于每次开机多一次 flash 写（配置在 /userdata，是实打实的磁盘 I/O）。
        return true;
    }
    return _save();
}

} // namespace mod
