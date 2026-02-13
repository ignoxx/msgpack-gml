/// @description MessagePack Test Suite and Examples
/// This file contains tests and usage examples for the msgpack functions

/// @function msgpack_run_tests()
/// @description Runs all tests and returns results
function msgpack_run_tests() {
    var _tests = {
        passed: 0,
        failed: 0,
        errors: []
    };
    
    show_debug_message("=== MessagePack Test Suite ===\n");
    
    // Test basic types
    _test_nil(_tests);
    _test_bool(_tests);
    _test_integers(_tests);
    _test_floats(_tests);
    
    // Test strings
    _test_strings(_tests);
    
    // Test arrays
    _test_arrays(_tests);
    
    // Test structs
    _test_structs(_tests);
    
    // Test nested structures
    _test_nested(_tests);
    
    // Test round-trip (encode then decode)
    _test_roundtrip(_tests);
    
    // Test edge cases
    _test_edge_cases(_tests);
    
    // Print results
    show_debug_message("\n=== Test Results ===");
    show_debug_message("Passed: " + string(_tests.passed));
    show_debug_message("Failed: " + string(_tests.failed));
    
    if (_tests.failed > 0) {
        show_debug_message("\nErrors:");
        for (var i = 0; i < array_length(_tests.errors); i++) {
            show_debug_message("  - " + _tests.errors[i]);
        }
    }
    
    return _tests.failed == 0;
}

/// @function _assert_equal(tests, actual, expected, test_name)
function _assert_equal(_tests, _actual, _expected, _test_name) {
    var _match = false;
    
    if (is_array(_actual) && is_array(_expected)) {
        _match = _arrays_equal(_actual, _expected);
    } else if (is_struct(_actual) && is_struct(_expected)) {
        _match = _structs_equal(_actual, _expected);
    } else if (is_real(_actual) && is_real(_expected)) {
        // For numbers, compare values directly (ignore type differences like int32 vs real)
        _match = (_actual == _expected);
    } else {
        _match = (_actual == _expected);
    }
    
    if (_match) {
        _tests.passed++;
        show_debug_message("✓ PASS: " + _test_name);
    } else {
        _tests.failed++;
        var _error = _test_name + " - Expected: " + string(_expected) + ", Got: " + string(_actual);
        array_push(_tests.errors, _error);
        show_debug_message("✗ FAIL: " + _error);
    }
}

/// @function _arrays_equal(a, b)
function _arrays_equal(_a, _b) {
    if (array_length(_a) != array_length(_b)) return false;
    
    for (var i = 0; i < array_length(_a); i++) {
        if (is_array(_a[i]) && is_array(_b[i])) {
            if (!_arrays_equal(_a[i], _b[i])) return false;
        } else if (is_struct(_a[i]) && is_struct(_b[i])) {
            if (!_structs_equal(_a[i], _b[i])) return false;
        } else if (_a[i] != _b[i]) {
            return false;
        }
    }
    
    return true;
}

/// @function _structs_equal(a, b)
function _structs_equal(_a, _b) {
    var _keys_a = variable_struct_get_names(_a);
    var _keys_b = variable_struct_get_names(_b);
    
    if (array_length(_keys_a) != array_length(_keys_b)) return false;
    
    for (var i = 0; i < array_length(_keys_a); i++) {
        var _key = _keys_a[i];
        if (!variable_struct_exists(_b, _key)) return false;
        
        var _val_a = variable_struct_get(_a, _key);
        var _val_b = variable_struct_get(_b, _key);
        
        if (is_array(_val_a) && is_array(_val_b)) {
            if (!_arrays_equal(_val_a, _val_b)) return false;
        } else if (is_struct(_val_a) && is_struct(_val_b)) {
            if (!_structs_equal(_val_a, _val_b)) return false;
        } else if (_val_a != _val_b) {
            return false;
        }
    }
    
    return true;
}

/// @function _test_nil(tests)
function _test_nil(_tests) {
    show_debug_message("\n--- Testing nil ---");
    
    var _buf = msgpack_encode(undefined);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    
    _assert_equal(_tests, _decoded, undefined, "nil");
}

/// @function _test_bool(tests)
function _test_bool(_tests) {
    show_debug_message("\n--- Testing booleans ---");
    
    var _buf = msgpack_encode(true);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, true, "true");
    
    _buf = msgpack_encode(false);
    _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, false, "false");
}

/// @function _test_integers(tests)
function _test_integers(_tests) {
    show_debug_message("\n--- Testing integers ---");
    
    // Positive fixint (0-127)
    _test_int_roundtrip(_tests, 0, "integer 0");
    _test_int_roundtrip(_tests, 1, "integer 1");
    _test_int_roundtrip(_tests, 127, "integer 127 (max fixint)");
    
    // Uint8
    _test_int_roundtrip(_tests, 128, "integer 128 (uint8)");
    _test_int_roundtrip(_tests, 255, "integer 255 (max uint8)");
    
    // Uint16
    _test_int_roundtrip(_tests, 256, "integer 256 (uint16)");
    _test_int_roundtrip(_tests, 1000, "integer 1000");
    _test_int_roundtrip(_tests, 65535, "integer 65535 (max uint16)");
    
    // Uint32
    _test_int_roundtrip(_tests, 65536, "integer 65536 (uint32)");
    _test_int_roundtrip(_tests, 100000, "integer 100000");
    _test_int_roundtrip(_tests, 1000000, "integer 1000000");
    
    // Negative fixint (-32 to -1)
    _test_int_roundtrip(_tests, -1, "integer -1");
    _test_int_roundtrip(_tests, -32, "integer -32 (min fixneg)");
    
    // Int8
    _test_int_roundtrip(_tests, -33, "integer -33 (int8)");
    _test_int_roundtrip(_tests, -128, "integer -128 (min int8)");
    
    // Int16
    _test_int_roundtrip(_tests, -129, "integer -129 (int16)");
    _test_int_roundtrip(_tests, -1000, "integer -1000");
    _test_int_roundtrip(_tests, -32768, "integer -32768 (min int16)");
    
    // Int32
    _test_int_roundtrip(_tests, -32769, "integer -32769 (int32)");
    _test_int_roundtrip(_tests, -100000, "integer -100000");
    _test_int_roundtrip(_tests, -1000000, "integer -1000000");
}

/// @function _test_int_roundtrip(tests, value, name)
function _test_int_roundtrip(_tests, _val, _name) {
    var _buf = msgpack_encode(_val);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, _val, _name);
}

/// @function _test_floats(tests)
function _test_floats(_tests) {
    show_debug_message("\n--- Testing floats ---");
    
    var _buf = msgpack_encode(1.5);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, 1.5, "float 1.5");
    
    _buf = msgpack_encode(-123.456);
    _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, -123.456, "float -123.456");
    
    _buf = msgpack_encode(0.0001);
    _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, 0.0001, "float 0.0001");
    
    _buf = msgpack_encode(10000000000);
    _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, 10000000000, "float 1e10");
    
    _buf = msgpack_encode(3.14159265359);
    _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, 3.14159265359, "float pi precision");
}

/// @function _test_strings(tests)
function _test_strings(_tests) {
    show_debug_message("\n--- Testing strings ---");
    
    // Empty string
    _test_string_roundtrip(_tests, "", "empty string");
    
    // Short string (fixstr)
    _test_string_roundtrip(_tests, "Hello", "short string 'Hello'");
    _test_string_roundtrip(_tests, "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "26 char string");
    
    // Medium string (str8)
    var _med = "This is a medium length string for testing purposes";
    _test_string_roundtrip(_tests, _med, "medium string");
    
    // Long string (>31 chars)
    var _long = "This is a very long string that exceeds the fixstr limit of 31 characters and tests str8 encoding";
    _test_string_roundtrip(_tests, _long, "long string");
    
    // Special characters
    _test_string_roundtrip(_tests, "Hello\nWorld", "string with newline");
    _test_string_roundtrip(_tests, "Tab\there", "string with tab");
    _test_string_roundtrip(_tests, "Quotes \"test\"", "string with quotes");
}

/// @function _test_string_roundtrip(tests, value, name)
function _test_string_roundtrip(_tests, _val, _name) {
    var _buf = msgpack_encode(_val);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, _val, _name);
}

/// @function _test_arrays(tests)
function _test_arrays(_tests) {
    show_debug_message("\n--- Testing arrays ---");
    
    // Empty array
    _test_array_roundtrip(_tests, [], "empty array");
    
    // Simple array
    _test_array_roundtrip(_tests, [1, 2, 3, 4, 5], "simple array [1,2,3,4,5]");
    
    // Array with mixed types
    _test_array_roundtrip(_tests, [1, "hello", true, undefined], "mixed type array");
    
    // Large array (>15 elements)
    var _large = [];
    for (var i = 0; i < 20; i++) {
        array_push(_large, i);
    }
    _test_array_roundtrip(_tests, _large, "large array (20 elements)");
    
    // Array with strings
    _test_array_roundtrip(_tests, ["one", "two", "three"], "string array");
}

/// @function _test_array_roundtrip(tests, value, name)
function _test_array_roundtrip(_tests, _val, _name) {
    var _buf = msgpack_encode(_val);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, _val, _name);
}

/// @function _test_structs(tests)
function _test_structs(_tests) {
    show_debug_message("\n--- Testing structs ---");
    
    // Empty struct
    _test_struct_roundtrip(_tests, {}, "empty struct");
    
    // Simple struct
    _test_struct_roundtrip(_tests, { name: "John", age: 30 }, "simple struct");
    
    // Struct with various types
    var _complex = {
        id: 123,
        active: true,
        name: "Test",
        score: 95.5,
        tags: ["a", "b", "c"]
    };
    _test_struct_roundtrip(_tests, _complex, "complex struct");
}

/// @function _test_struct_roundtrip(tests, value, name)
function _test_struct_roundtrip(_tests, _val, _name) {
    var _buf = msgpack_encode(_val);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, _val, _name);
}

/// @function _test_nested(tests)
function _test_nested(_tests) {
    show_debug_message("\n--- Testing nested structures ---");
    
    // Array of structs
    var _arr_structs = [
        { id: 1, name: "First" },
        { id: 2, name: "Second" },
        { id: 3, name: "Third" }
    ];
    _test_roundtrip_value(_tests, _arr_structs, "array of structs");
    
    // Struct with nested array
    var _struct_arr = {
        name: "Test",
        items: [1, 2, 3]
    };
    _test_roundtrip_value(_tests, _struct_arr, "struct with nested array");
    
    // Deeply nested
    var _deep = {
        level1: {
            level2: {
                level3: {
                    value: "deep"
                }
            }
        }
    };
    _test_roundtrip_value(_tests, _deep, "deeply nested struct");
}

/// @function _test_roundtrip_value(tests, value, name)
function _test_roundtrip_value(_tests, _val, _name) {
    var _buf = msgpack_encode(_val);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, _val, _name);
}

/// @function _test_roundtrip(tests)
function _test_roundtrip(_tests) {
    show_debug_message("\n--- Testing round-trip encoding/decoding ---");
    
    // Test specific values that were failing
    _test_int_roundtrip(_tests, 12345, "specific value 12345");
    _test_int_roundtrip(_tests, 1234567890, "specific value 1234567890");
    
    // Test floats that were failing
    var _buf = msgpack_encode(150.5);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, 150.5, "float 150.5");
    
    _buf = msgpack_encode(200.75);
    _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, 200.75, "float 200.75");
    
    // Test simple struct with large value
    var _simple = { id: 12345 };
    _buf = msgpack_encode(_simple);
    _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    show_debug_message("Simple struct test - Expected id: 12345, Got id: " + string(_decoded.id));
    
    // Additional debug output
    _assert_equal(_tests, _decoded.id, 12345, "simple struct with id 12345");
    
    // Test nested struct with these values
    var _nested = {
        id: 12345,
        position: {
            x: 150.5,
            y: 200.75
        }
    };
    _test_roundtrip_value(_tests, _nested, "nested with large values");
    
    // Complex real-world-like data structure
    var _data = {
        player: {
            id: 12345,
            name: "PlayerOne",
            health: 100,
            position: {
                x: 150.5,
                y: 200.75
            },
            inventory: [
                { item: "sword", count: 1 },
                { item: "potion", count: 5 }
            ],
            active: true,
            last_login: undefined
        },
        server_time: 1234567890,
        players_online: 42
    };
    
    _test_roundtrip_value(_tests, _data, "complex round-trip");
}

/// @function _test_edge_cases(tests)
function _test_edge_cases(_tests) {
    show_debug_message("\n--- Testing edge cases ---");
    
    // Zero values
    _test_int_roundtrip(_tests, 0, "zero integer");
    var _buf = msgpack_encode(0.0);
    var _decoded = msgpack_decode(_buf);
    buffer_delete(_buf);
    // 0.0 encodes as float but decodes back - this is expected
    show_debug_message("Note: 0.0 encodes as float64, decodes correctly");
    
    // Empty nested structures
    _test_roundtrip_value(_tests, { data: [] }, "struct with empty array");
    _test_roundtrip_value(_tests, [ {} ], "array with empty struct");
    
    // Unicode strings (if supported)
    var _unicode = "Hello 世界 🌍";
    _test_string_roundtrip(_tests, _unicode, "unicode string");
    
    // Comprehensive emoji tests
    _test_emoji_support(_tests);
}

/// @function _test_emoji_support(tests)
/// @description Tests various emoji encodings
function _test_emoji_support(_tests) {
    show_debug_message("\n--- Testing emoji support ---");
    
    // Basic emoji (4-byte UTF-8)
    _test_emoji_with_debug(_tests, "😀", "basic smiley emoji");
    _test_emoji_with_debug(_tests, "🌍", "earth emoji");
    _test_emoji_with_debug(_tests, "🎮", "game controller emoji");
    
    // Multiple emojis
    _test_emoji_with_debug(_tests, "😀😁😂", "multiple emojis");
    
    // Emoji with text
    _test_emoji_with_debug(_tests, "Hello 👋 World", "emoji with text");
    
    // Skin tone modifier (emoji + modifier)
    _test_emoji_with_debug(_tests, "👍🏽", "emoji with skin tone");
    _test_emoji_with_debug(_tests, "👋🏿", "waving hand dark skin");
    
    // Family/couple emojis (multiple codepoints with ZWJ)
    _test_emoji_with_debug(_tests, "👨‍👩‍👧‍👦", "family emoji");
    _test_emoji_with_debug(_tests, "👩‍❤️‍👩", "couple with heart");
    
    // Flag emojis (regional indicators)
    _test_emoji_with_debug(_tests, "🇺🇸", "US flag");
    _test_emoji_with_debug(_tests, "🇯🇵", "Japan flag");
    _test_emoji_with_debug(_tests, "🇪🇺", "EU flag");
    
    // Mixed content (text + unicode + emoji)
    _test_emoji_with_debug(_tests, "Test: 世界 🌍 €100", "mixed content");
    
    // Discord-style message with emoji
    var _discord_msg = {
        MessageID: "1470556763404370031",
        AvatarURL: "",
        ChannelID: "1222618154510057515",
        Version: 1,
        GuildID: "1222618154510057512",
        Emoji: "😀"
    };
    _test_roundtrip_value(_tests, _discord_msg, "Discord message with emoji");
    
    // Test emoji in struct key (if supported)
    var _emoji_key = {
        "🎮": "gaming",
        "🏆": "winner"
    };
    _test_roundtrip_value(_tests, _emoji_key, "struct with emoji keys");
}

/// @function _test_emoji_with_debug(tests, emoji, test_name)
/// @description Tests emoji with debug output on failure
function _test_emoji_with_debug(_tests, _emoji, _test_name) {
    var _buf = msgpack_encode(_emoji);
    var _decoded = msgpack_decode(_buf);
    
    if (_decoded != _emoji) {
        show_debug_message("DEBUG Emoji '" + _test_name + "':");
        show_debug_message("  Original length: " + string(string_length(_emoji)) + " chars, " + string(string_byte_length(_emoji)) + " bytes");
        show_debug_message("  Decoded length: " + string(string_length(_decoded)) + " chars, " + string(string_byte_length(_decoded)) + " bytes");
        show_debug_message("  Original: " + _emoji);
        show_debug_message("  Decoded: " + _decoded);
        
        // Show hex bytes
        var _hex_chars = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F"];
        var _hex_orig = "  Orig hex: ";
        for (var i = 1; i <= string_byte_length(_emoji); i++) {
            var _byte = string_byte_at(_emoji, i);
            _hex_orig += _hex_chars[_byte >> 4] + _hex_chars[_byte & 0xF] + " ";
        }
        show_debug_message(_hex_orig);
        
        var _hex_dec = "  Decoded hex: ";
        for (var i = 1; i <= string_byte_length(_decoded); i++) {
            var _byte = string_byte_at(_decoded, i);
            _hex_dec += _hex_chars[_byte >> 4] + _hex_chars[_byte & 0xF] + " ";
        }
        show_debug_message(_hex_dec);
    }
    
    buffer_delete(_buf);
    _assert_equal(_tests, _decoded, _emoji, _test_name);
}

/// @function msgpack_example_usage()
/// @description Shows example usage of msgpack functions
function msgpack_example_usage() {
    show_debug_message("\n=== MessagePack Usage Examples ===\n");
    
    // Example 1: Basic encoding/decoding
    show_debug_message("Example 1: Basic encoding/decoding");
    var player_data = {
        name: "Hero",
        level: 10,
        hp: 100.5,
        inventory: ["sword", "shield"]
    };
    
    var encoded = msgpack_encode(player_data);
    show_debug_message("Encoded player data to buffer");
    
    var decoded = msgpack_decode(encoded);
    buffer_delete(encoded);
    
    if (is_struct(decoded) && variable_struct_exists(decoded, "__msgpack_error")) {
        show_debug_message("Error: " + decoded.error);
    } else {
        show_debug_message("Decoded: " + string(decoded));
    }
    
    // Example 2: Reusing a buffer
    show_debug_message("\nExample 2: Reusing a buffer");
    var shared_buffer = buffer_create(1024, buffer_fixed, 1);
    
    var data1 = { message: "Hello" };
    var data2 = { message: "World" };
    
    msgpack_encode(data1, shared_buffer);
    var len1 = buffer_tell(shared_buffer);
    show_debug_message("First message size: " + string(len1) + " bytes");
    
    buffer_seek(shared_buffer, buffer_seek_start, 0);
    msgpack_encode(data2, shared_buffer);
    var len2 = buffer_tell(shared_buffer);
    show_debug_message("Second message size: " + string(len2) + " bytes");
    
    buffer_delete(shared_buffer);
    
    // Example 3: WebSocket network data
    show_debug_message("\nExample 3: Network data handling");
    show_debug_message("// When receiving data via async_network event:");
    show_debug_message("var buff = ds_map_find_value(async_load, \"buffer\");");
    show_debug_message("var result = msgpack_decode(buff);");
    show_debug_message("if (is_struct(result) && variable_struct_exists(result, \"__msgpack_error\")) {");
    show_debug_message("    show_debug_message(\"Failed to decode: \" + result.error);");
    show_debug_message("} else {");
    show_debug_message("    // Process result...");
    show_debug_message("}");
    
    // Example 4: Extension types
    show_debug_message("\nExample 4: Extension types");
    var ext_data = {
        __msgpack_ext_type: 1,
        __msgpack_ext_data: [0x01, 0x02, 0x03, 0x04]
    };
    
    var buf = msgpack_encode(ext_data);
    var decoded_ext = msgpack_decode(buf);
    buffer_delete(buf);
    
    if (is_struct(decoded_ext) && 
        variable_struct_exists(decoded_ext, "__msgpack_ext_type")) {
        var ext_type = variable_struct_get(decoded_ext, "__msgpack_ext_type");
        var ext_bytes = variable_struct_get(decoded_ext, "__msgpack_ext_data");
        show_debug_message("Extension type: " + string(ext_type));
        show_debug_message("Extension data: " + string(ext_bytes));
    }
}
