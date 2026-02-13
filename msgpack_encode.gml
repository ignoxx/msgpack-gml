/// @function msgpack_encode(value, [buffer])
/// @description Encodes a GML value into MessagePack format
/// @param {Any} value The value to encode (real, string, bool, array, struct, or undefined)
/// @param {Id.Buffer} [buffer] Optional existing buffer to write to. If not provided, a new buffer is created.
/// @return {Id.Buffer|Struct} The buffer with encoded data, or an error struct on failure
/// @pure

function msgpack_encode(_value, _buffer = -1) {
    var _encoder = new __msgpack_encoder();
    return _encoder.encode(_value, _buffer);
}

/// @function __msgpack_encoder
/// @description Internal encoder class for MessagePack
function __msgpack_encoder() constructor {
    scratch = buffer_create(8, buffer_fixed, 1);
    
    /// @function encode(value, [buffer])
    /// @description Encodes a value to MessagePack format
    static encode = function(_value, _buffer = -1) {
        if (_buffer == -1 || !buffer_exists(_buffer)) {
            buffer = buffer_create(256, buffer_grow, 1);
        } else {
            buffer = _buffer;
            buffer_seek(buffer, buffer_seek_start, 0);
        }
        
        var _result = __encode_value(_value);
        
        buffer_delete(scratch);
        
        if (is_struct(_result) && variable_struct_exists(_result, "__msgpack_error")) {
            if (_buffer == -1) {
                buffer_delete(buffer);
            }
            return _result;
        }
        
        buffer_seek(buffer, buffer_seek_start, 0);
        return buffer;
    };
    
    /// @function __encode_value(value)
    /// @description Encodes a single value
    static __encode_value = function(_value) {
        var _type = typeof(_value);
        
        switch (_type) {
            case "undefined":
                __write_u8(MSGPACK_NIL);
                return true;
                
            case "bool":
            case "boolean":
                __write_u8(_value ? MSGPACK_TRUE : MSGPACK_FALSE);
                return true;
                
            case "number":
            case "int32":
            case "int64":
            case "real":
                return __encode_number(_value);
                
            case "string":
                return __encode_string(_value);
                
            case "array":
                return __encode_array(_value);
                
            case "struct":
                return __encode_struct(_value);
                
            default:
                return __create_error("Unsupported type: " + _type);
        }
    };
    
    /// @function __encode_number(num)
    /// @description Encodes a number (integer or float)
    static __encode_number = function(_num) {
        if (is_nan(_num)) {
            return __create_error("NaN cannot be encoded in MessagePack");
        }
        
        if (is_infinity(_num)) {
            return __create_error("Infinity cannot be encoded in MessagePack");
        }
        
        if (_num == floor(_num)) {
            // Integer encoding
            if (_num >= 0) {
                if (_num <= 0x7f) {
                    // Positive fixint
                    __write_u8(_num);
                } else if (_num <= 0xff) {
                    // uint8
                    __write_u8(MSGPACK_UINT8);
                    __write_u8(_num);
                } else if (_num <= 0xffff) {
                    // uint16
                    __write_u8(MSGPACK_UINT16);
                    __write_u16_be(_num);
                } else if (_num <= 0xffffffff) {
                    // uint32
                    __write_u8(MSGPACK_UINT32);
                    __write_u32_be(_num);
                } else {
                    // uint64 (as float64)
                    __write_u8(MSGPACK_FLOAT64);
                    __write_f64_be(_num);
                }
            } else {
                if (_num >= -32) {
                    // Negative fixint
                    __write_s8(_num);
                } else if (_num >= -128) {
                    // int8
                    __write_u8(MSGPACK_INT8);
                    __write_s8(_num);
                } else if (_num >= -32768) {
                    // int16
                    __write_u8(MSGPACK_INT16);
                    __write_s16_be(_num);
                } else if (_num >= -2147483648) {
                    // int32
                    __write_u8(MSGPACK_INT32);
                    __write_s32_be(_num);
                } else {
                    // int64 (as float64)
                    __write_u8(MSGPACK_FLOAT64);
                    __write_f64_be(_num);
                }
            }
        } else {
            // Float encoding - use float64 for precision
            __write_u8(MSGPACK_FLOAT64);
            __write_f64_be(_num);
        }
        
        return true;
    };
    
    /// @function __encode_string(str)
    /// @description Encodes a string as UTF-8
    static __encode_string = function(_str) {
        var _len = string_byte_length(_str);
        
        if (_len <= 31) {
            // Fixstr
            __write_u8(0xa0 | _len);
        } else if (_len <= 0xff) {
            // str8
            __write_u8(MSGPACK_STR8);
            __write_u8(_len);
        } else if (_len <= 0xffff) {
            // str16
            __write_u8(MSGPACK_STR16);
            __write_u16_be(_len);
        } else {
            // str32
            __write_u8(MSGPACK_STR32);
            __write_u32_be(_len);
        }
        
        // Write UTF-8 bytes directly (no null terminator)
        var _str_buff = buffer_create(_len, buffer_fixed, 1);
        buffer_write(_str_buff, buffer_text, _str);
        buffer_copy(_str_buff, 0, _len, buffer, buffer_tell(buffer));
        buffer_seek(buffer, buffer_seek_relative, _len);
        buffer_delete(_str_buff);
        
        return true;
    };
    
    /// @function __encode_array(arr)
    /// @description Encodes an array
    static __encode_array = function(_arr) {
        var _len = array_length(_arr);
        
        if (_len <= 15) {
            // Fixarray
            __write_u8(0x90 | _len);
        } else if (_len <= 0xffff) {
            // array16
            __write_u8(MSGPACK_ARRAY16);
            __write_u16_be(_len);
        } else {
            // array32
            __write_u8(MSGPACK_ARRAY32);
            __write_u32_be(_len);
        }
        
        for (var i = 0; i < _len; i++) {
            var _result = __encode_value(_arr[i]);
            if (is_struct(_result) && variable_struct_exists(_result, "__msgpack_error")) {
                return _result;
            }
        }
        
        return true;
    };
    
    /// @function __encode_struct(struct)
    /// @description Encodes a struct as a MessagePack map
    static __encode_struct = function(_struct) {
        if (variable_struct_exists(_struct, MSGPACK_EXT_STRUCT_KEY_TYPE) && 
            variable_struct_exists(_struct, MSGPACK_EXT_STRUCT_KEY_DATA)) {
            return __encode_extension(_struct);
        }
        
        if (variable_struct_exists(_struct, "__msgpack_error")) {
            return __create_error("Cannot encode error struct");
        }
        
        var _names = variable_struct_get_names(_struct);
        var _len = array_length(_names);
        
        if (_len <= 15) {
            // Fixmap
            __write_u8(0x80 | _len);
        } else if (_len <= 0xffff) {
            // map16
            __write_u8(MSGPACK_MAP16);
            __write_u16_be(_len);
        } else {
            // map32
            __write_u8(MSGPACK_MAP32);
            __write_u32_be(_len);
        }
        
        for (var i = 0; i < _len; i++) {
            var _key = _names[i];
            var _val = variable_struct_get(_struct, _key);
            
            var _result = __encode_string(_key);
            if (is_struct(_result) && variable_struct_exists(_result, "__msgpack_error")) {
                return _result;
            }
            
            _result = __encode_value(_val);
            if (is_struct(_result) && variable_struct_exists(_result, "__msgpack_error")) {
                return _result;
            }
        }
        
        return true;
    };
    
    /// @function __encode_extension(ext_struct)
    /// @description Encodes an extension type struct
    static __encode_extension = function(_ext) {
        var _type = variable_struct_get(_ext, MSGPACK_EXT_STRUCT_KEY_TYPE);
        var _data = variable_struct_get(_ext, MSGPACK_EXT_STRUCT_KEY_DATA);
        
        if (!is_array(_data)) {
            return __create_error("Extension data must be an array");
        }
        
        var _len = array_length(_data);
        
        if (_len == 1) {
            __write_u8(MSGPACK_FIXEXT1);
        } else if (_len == 2) {
            __write_u8(MSGPACK_FIXEXT2);
        } else if (_len == 4) {
            __write_u8(MSGPACK_FIXEXT4);
        } else if (_len == 8) {
            __write_u8(MSGPACK_FIXEXT8);
        } else if (_len == 16) {
            __write_u8(MSGPACK_FIXEXT16);
        } else if (_len <= 0xff) {
            __write_u8(MSGPACK_EXT8);
            __write_u8(_len);
        } else if (_len <= 0xffff) {
            __write_u8(MSGPACK_EXT16);
            __write_u16_be(_len);
        } else {
            __write_u8(MSGPACK_EXT32);
            __write_u32_be(_len);
        }
        
        __write_s8(_type);
        
        for (var i = 0; i < _len; i++) {
            __write_u8(_data[i]);
        }
        
        return true;
    };
    
    // Write functions with little-endian to big-endian conversion
    static __write_u8 = function(_val) {
        buffer_write(buffer, buffer_u8, _val);
    };
    
    static __write_s8 = function(_val) {
        buffer_write(buffer, buffer_s8, _val);
    };
    
    static __write_u16_be = function(_val) {
        buffer_poke(scratch, 0, buffer_u16, _val);
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 1, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 0, buffer_u8));
    };
    
    static __write_u32_be = function(_val) {
        buffer_poke(scratch, 0, buffer_u32, _val);
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 3, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 2, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 1, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 0, buffer_u8));
    };
    
    static __write_s16_be = function(_val) {
        buffer_poke(scratch, 0, buffer_s16, _val);
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 1, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 0, buffer_u8));
    };
    
    static __write_s32_be = function(_val) {
        buffer_poke(scratch, 0, buffer_s32, _val);
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 3, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 2, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 1, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 0, buffer_u8));
    };
    
    static __write_f64_be = function(_val) {
        buffer_poke(scratch, 0, buffer_f64, _val);
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 7, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 6, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 5, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 4, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 3, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 2, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 1, buffer_u8));
        buffer_write(buffer, buffer_u8, buffer_peek(scratch, 0, buffer_u8));
    };
    
    static __create_error = function(_message) {
        return {
            __msgpack_error: true,
            success: false,
            error: _message
        };
    };
}
