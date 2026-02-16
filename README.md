# MessagePack for GameMaker Studio 2.3+

Pure GML implementation of MessagePack encoding/decoding for GameMaker Studio 2.3+.

## Quick Start

**Important**: After encoding, the buffer is seeked to position 0 (to allow reading from the start), so `buffer_tell()` will return 0. Use `buffer_get_size(buffer)` to get the actual encoded data length.

```gml
// Encode data to MessagePack
var data = { name: "Player", health: 100, position: { x: 100, y: 200 } };
var buffer = msgpack_encode(data);

// Check for encoding errors
if (is_struct(buffer) && variable_struct_exists(buffer, "__msgpack_error")) {
    show_debug_message("Encode error: " + buffer.error);
    return;
}

// Send over network - use buffer_get_size, not buffer_tell (buffer is seeked to 0 after encoding)
network_send_raw(socket, buffer, buffer_get_size(buffer));
buffer_delete(buffer);

// Decode received data
var msg = msgpack_decode(async_load[? "buffer"]);
show_debug_message(msg.name); // "Player"
```

## Features

- **Pure GML** - No extensions or DLLs
- **Fast** - Optimized encoding with smallest format selection
- **Complete** - Supports all MessagePack types
- **Modern** - Uses GML 2.3+ structs and arrays (not ds_map/ds_list)
- **Safe** - Returns error structs on failure

## Installation

1. Copy all `.gml` files to your project's scripts folder
2. Done!

## Type Mapping

| MessagePack | GML |
|------------|-----|
| `nil` | `undefined` |
| `bool` | `true`/`false` |
| `int*` | `real` (integer) |
| `float*` | `real` (double precision) |
| `str*` | `string` (UTF-8, including emoji) |
| `bin*` | `array` of bytes |
| `array*` | `array` |
| `map*` | `struct` |
| `ext*` | special struct (see below) |

## Examples

### WebSocket / TCP Network Message

```gml
// Async - Networking event
if (async_load[? "type"] == network_type_data) {
    var buff = async_load[? "buffer"];
    var msg = msgpack_decode(buff);
    
    // Check for errors
    if (is_struct(msg) && variable_struct_exists(msg, "__msgpack_error")) {
        show_debug_message("Decode error: " + msg.error);
        exit;
    }
    
    // Handle message
    switch (msg.type) {
        case "player_move":
            x = msg.x;
            y = msg.y;
            break;
            
        case "chat":
            show_chat_message(msg.user, msg.text);
            break;
    }
}
```

### Encoding Game Data

```gml
// Encode player data
function save_player_data() {
    var player = {
        name: global.player_name,
        level: global.player_level,
        inventory: global.inventory,
        position: {
            x: obj_player.x,
            y: obj_player.y
        }
    };
    
    var buff = msgpack_encode(player);
    if (is_struct(buff) && variable_struct_exists(buff, "__msgpack_error")) {
        show_debug_message("Encode error: " + buff.error);
        return;
    }
    buffer_save(buff, "player.dat");
    buffer_delete(buff);
}

// Encode for network
function send_player_position() {
    var msg = {
        type: "player_move",
        x: x,
        y: y,
        timestamp: current_time
    };
    
    var buff = msgpack_encode(msg);
    network_send_raw(socket, buff, buffer_get_size(buff));
    buffer_delete(buff);
}
```

### Converting ds_map (Legacy Support)

```gml
// Convert ds_map to struct for encoding
function ds_map_to_struct(ds_map) {
    var struct = {};
    var keys = ds_map_keys_to_array(ds_map);
    
    for (var i = 0; i < array_length(keys); i++) {
        var key = keys[i];
        var val = ds_map_find_value(ds_map, key);
        
        // Handle nested ds_map
        if (is_real(val) && ds_exists(val, ds_type_map)) {
            val = ds_map_to_struct(val);
        }
        
        variable_struct_set(struct, key, val);
    }
    
    return struct;
}

// Usage
var my_map = ds_map_create();
ds_map_add(my_map, "name", "Player");
ds_map_add(my_map, "score", 1000);

var struct = ds_map_to_struct(my_map);
var buff = msgpack_encode(struct);
// ... send or save ...
buffer_delete(buff);
ds_map_destroy(my_map);
```

### Buffer Reuse (Performance)

```gml
// Reuse buffer to avoid allocations
var shared_buffer = buffer_create(1024, buffer_fixed, 1);

function send_message(msg) {
    buffer_seek(shared_buffer, buffer_seek_start, 0);
    msgpack_encode(msg, shared_buffer);
    network_send_raw(socket, shared_buffer, buffer_get_size(shared_buffer));
}

// Send multiple messages
send_message({ type: "ping" });
send_message({ type: "pong" });
send_message({ type: "data", value: 42 });

buffer_delete(shared_buffer);
```

## Extension Types

Extension types are decoded as special structs:

```gml
{
    __msgpack_ext_type: 1,    // Type ID (-128 to 127)
    __msgpack_ext_data: [     // Binary data as byte array
        0x01, 0x02, 0x03, 0x04
    ]
}
```

To encode extension data:

```gml
var ext = {
    __msgpack_ext_type: 1,
    __msgpack_ext_data: [0x01, 0x02, 0x03]
};
var buff = msgpack_encode(ext);
```

## Error Handling

On error, functions return a struct:

```gml
{
    __msgpack_error: true,
    success: false,
    error: "Error message",
    position: 42  // Byte position (decoder only)
}
```

Check for errors:

```gml
var result = msgpack_decode(buffer);

if (is_struct(result) && variable_struct_exists(result, "__msgpack_error")) {
    show_debug_message("Error at position " + string(result.position) + ": " + result.error);
} else {
    // Use result normally
}
```

## Testing

Run the test suite:

```gml
msgpack_run_tests();      // Run all tests
msgpack_example_usage();  // Show usage examples
```

## Limitations

- **64-bit integers**: Decoded as real numbers (may lose precision for very large values > 2^53)
- **Map keys**: Must be strings (MessagePack allows any type, but GML struct keys are strings)
- **NaN/Infinity**: Cannot be encoded (MessagePack spec limitation)
- **Circular references**: Not detected (will cause stack overflow)

## Files

- `msgpack_constants.gml` - Format constants
- `msgpack_decode.gml` - `msgpack_decode(buffer)` function
- `msgpack_encode.gml` - `msgpack_encode(value, [buffer])` function
- `msgpack_tests.gml` - Test suite and examples

## License

MIT License - Free for commercial and non-commercial use.

## Credits

Created for GameMaker Studio 2.3+

Based on and inspired by [GM-MessagePack by meseta](https://meseta.itch.io/gm-msgpack) - the original GameMaker MessagePack library that this implementation builds upon.
