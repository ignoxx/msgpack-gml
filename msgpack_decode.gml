/// @function msgpack_decode(buffer)
/// @description Decodes a MessagePack buffer into GML data structures
/// @param {Id.Buffer} buffer The buffer containing MessagePack data
/// @return {Any|Struct} The decoded data, or an error struct on failure
/// @pure

function msgpack_decode(_buffer) {
    var _decoder = new __msgpack_decoder(_buffer);
    return _decoder.decode();
}

/// @function __msgpack_decoder
/// @description Internal decoder class for MessagePack
/// @param {Id.Buffer} buffer The buffer to decode from
function __msgpack_decoder(_buffer) constructor {
    buffer = _buffer;
    length = buffer_get_size(_buffer);
    position = 0;
    scratch = buffer_create(8, buffer_fixed, 1);
    
    /// @function decode()
    /// @description Decodes the entire buffer
    /// @return {Any|Struct} Decoded value or error struct
    static decode = function() {
        if (length == 0) {
            buffer_delete(scratch);
            return __create_error(MSGPACK_ERROR_UNEXPECTED_END, 0);
        }
        
        var _result = __decode_value();
        buffer_delete(scratch);
        
        return _result;
    };
    
    /// @function __decode_value()
    /// @description Decodes a single MessagePack value
    /// @return {Any} Decoded value
    static __decode_value = function() {
        if (position >= length) {
            return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        }
        
        var _marker = __read_u8();
        
        // Positive fixint: 0x00 - 0x7f
        if (_marker <= 0x7f) {
            return _marker;
        }
        
        // Fixmap: 0x80 - 0x8f
        if (_marker >= 0x80 && _marker <= 0x8f) {
            return __decode_map(_marker & 0x0f);
        }
        
        // Fixarray: 0x90 - 0x9f
        if (_marker >= 0x90 && _marker <= 0x9f) {
            return __decode_array(_marker & 0x0f);
        }
        
        // Fixstr: 0xa0 - 0xbf
        if (_marker >= 0xa0 && _marker <= 0xbf) {
            return __decode_str(_marker & 0x1f);
        }
        
        // Negative fixint: 0xe0 - 0xff
        if (_marker >= 0xe0) {
            return _marker - 256; // Convert to signed
        }
        
        // Process other types
        switch (_marker) {
            case MSGPACK_NIL:
                return undefined;
                
            case MSGPACK_FALSE:
                return false;
                
            case MSGPACK_TRUE:
                return true;
                
            case MSGPACK_BIN8:
                return __decode_bin(__read_u8());
                
            case MSGPACK_BIN16:
                return __decode_bin(__read_u16_be());
                
            case MSGPACK_BIN32:
                return __decode_bin(__read_u32_be());
                
            case MSGPACK_EXT8:
                return __decode_ext(__read_u8());
                
            case MSGPACK_EXT16:
                return __decode_ext(__read_u16_be());
                
            case MSGPACK_EXT32:
                return __decode_ext(__read_u32_be());
                
            case MSGPACK_FLOAT32:
                return __read_f32_be();
                
            case MSGPACK_FLOAT64:
                return __read_f64_be();
                
            case MSGPACK_UINT8:
                return __read_u8();
                
            case MSGPACK_UINT16:
                return __read_u16_be();
                
            case MSGPACK_UINT32:
                return __read_u32_be();
                
            case MSGPACK_UINT64:
                // Read as two 32-bit values and combine
                var _high = __read_u32_be();
                var _low = __read_u32_be();
                return _high * 4294967296 + _low;
                
            case MSGPACK_INT8:
                return __read_s8();
                
            case MSGPACK_INT16:
                return __read_s16_be();
                
            case MSGPACK_INT32:
                return __read_s32_be();
                
            case MSGPACK_INT64:
                var _high = __read_s32_be();
                var _low = __read_u32_be();
                return _high * 4294967296 + _low;
                
            case MSGPACK_FIXEXT1:
                return __decode_ext(1);
                
            case MSGPACK_FIXEXT2:
                return __decode_ext(2);
                
            case MSGPACK_FIXEXT4:
                return __decode_ext(4);
                
            case MSGPACK_FIXEXT8:
                return __decode_ext(8);
                
            case MSGPACK_FIXEXT16:
                return __decode_ext(16);
                
            case MSGPACK_STR8:
                return __decode_str(__read_u8());
                
            case MSGPACK_STR16:
                return __decode_str(__read_u16_be());
                
            case MSGPACK_STR32:
                return __decode_str(__read_u32_be());
                
            case MSGPACK_ARRAY16:
                return __decode_array(__read_u16_be());
                
            case MSGPACK_ARRAY32:
                return __decode_array(__read_u32_be());
                
            case MSGPACK_MAP16:
                return __decode_map(__read_u16_be());
                
            case MSGPACK_MAP32:
                return __decode_map(__read_u32_be());
                
            default:
                return __create_error(MSGPACK_ERROR_INVALID_TYPE, position - 1);
        }
    };
    
    /// @function __decode_str(length)
    /// @description Decodes a UTF-8 string of given length
    static __decode_str = function(_len) {
        if (_len < 0) {
            return __create_error(MSGPACK_ERROR_INVALID_LENGTH, position);
        }
        
        if (position + _len > length) {
            return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        }
        
        // Decode UTF-8 bytes manually
        var _str = "";
        var _end = position + _len;
        
        while (position < _end) {
            var _byte1 = __read_u8();
            
            if ((_byte1 & 0x80) == 0) {
                // Single byte (ASCII)
                _str += chr(_byte1);
            } else if ((_byte1 & 0xe0) == 0xc0) {
                // 2-byte sequence
                if (position >= _end) return __create_error(MSGPACK_ERROR_INVALID_UTF8, position);
                var _byte2 = __read_u8();
                _str += chr(((_byte1 & 0x1f) << 6) | (_byte2 & 0x3f));
            } else if ((_byte1 & 0xf0) == 0xe0) {
                // 3-byte sequence
                if (position + 1 >= _end) return __create_error(MSGPACK_ERROR_INVALID_UTF8, position);
                var _byte2 = __read_u8();
                var _byte3 = __read_u8();
                _str += chr(((_byte1 & 0x0f) << 12) | ((_byte2 & 0x3f) << 6) | (_byte3 & 0x3f));
            } else if ((_byte1 & 0xf8) == 0xf0) {
                // 4-byte sequence (rare in practice)
                if (position + 2 >= _end) return __create_error(MSGPACK_ERROR_INVALID_UTF8, position);
                var _byte2 = __read_u8();
                var _byte3 = __read_u8();
                var _byte4 = __read_u8();
                // Combine into single value (may lose precision for very high codepoints in GML)
                var _codepoint = ((_byte1 & 0x07) << 18) | ((_byte2 & 0x3f) << 12) | ((_byte3 & 0x3f) << 6) | (_byte4 & 0x3f);
                _str += chr(_codepoint);
            } else {
                return __create_error(MSGPACK_ERROR_INVALID_UTF8, position - 1);
            }
        }
        
        return _str;
    };
    
    /// @function __decode_bin(length)
    /// @description Decodes binary data into an array of bytes
    static __decode_bin = function(_len) {
        if (_len < 0) {
            return __create_error(MSGPACK_ERROR_INVALID_LENGTH, position);
        }
        
        if (position + _len > length) {
            return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        }
        
        var _arr = array_create(_len);
        for (var i = 0; i < _len; i++) {
            _arr[i] = __read_u8();
        }
        
        return _arr;
    };
    
    /// @function __decode_ext(length)
    /// @description Decodes an extension type
    static __decode_ext = function(_len) {
        if (position >= length) {
            return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        }
        
        var _type = __read_s8();
        var _data = __decode_bin(_len);
        
        if (is_struct(_data) && variable_struct_exists(_data, "__msgpack_error")) {
            return _data;
        }
        
        var _ext = {};
        variable_struct_set(_ext, MSGPACK_EXT_STRUCT_KEY_TYPE, _type);
        variable_struct_set(_ext, MSGPACK_EXT_STRUCT_KEY_DATA, _data);
        
        return _ext;
    };
    
    /// @function __decode_array(element_count)
    /// @description Decodes an array of given element count
    static __decode_array = function(_count) {
        if (_count < 0) {
            return __create_error(MSGPACK_ERROR_INVALID_LENGTH, position);
        }
        
        var _arr = array_create(_count);
        
        for (var i = 0; i < _count; i++) {
            var _elem = __decode_value();
            
            if (is_struct(_elem) && variable_struct_exists(_elem, "__msgpack_error")) {
                return _elem;
            }
            
            _arr[i] = _elem;
        }
        
        return _arr;
    };
    
    /// @function __decode_map(pair_count)
    /// @description Decodes a map into a GML struct
    static __decode_map = function(_count) {
        if (_count < 0) {
            return __create_error(MSGPACK_ERROR_INVALID_LENGTH, position);
        }
        
        var _struct = {};
        
        for (var i = 0; i < _count; i++) {
            var _key = __decode_value();
            
            if (is_struct(_key) && variable_struct_exists(_key, "__msgpack_error")) {
                return _key;
            }
            
            if (!is_string(_key)) {
                return __create_error(MSGPACK_ERROR_KEY_NOT_STRING, position);
            }
            
            var _val = __decode_value();
            
            if (is_struct(_val) && variable_struct_exists(_val, "__msgpack_error")) {
                return _val;
            }
            
            variable_struct_set(_struct, _key, _val);
        }
        
        return _struct;
    };
    
    // Read functions with big-endian to little-endian conversion
    static __read_u8 = function() {
        return buffer_peek(buffer, position++, buffer_u8);
    };
    
    static __read_s8 = function() {
        return buffer_peek(buffer, position++, buffer_s8);
    };
    
    static __read_u16_be = function() {
        if (position + 2 > length) return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        // Read bytes in big-endian order, write to scratch in reverse
        buffer_poke(scratch, 1, buffer_u8, buffer_peek(buffer, position, buffer_u8));
        buffer_poke(scratch, 0, buffer_u8, buffer_peek(buffer, position + 1, buffer_u8));
        position += 2;
        return buffer_peek(scratch, 0, buffer_u16);
    };
    
    static __read_u32_be = function() {
        if (position + 4 > length) return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        buffer_poke(scratch, 3, buffer_u8, buffer_peek(buffer, position, buffer_u8));
        buffer_poke(scratch, 2, buffer_u8, buffer_peek(buffer, position + 1, buffer_u8));
        buffer_poke(scratch, 1, buffer_u8, buffer_peek(buffer, position + 2, buffer_u8));
        buffer_poke(scratch, 0, buffer_u8, buffer_peek(buffer, position + 3, buffer_u8));
        position += 4;
        return buffer_peek(scratch, 0, buffer_u32);
    };
    
    static __read_s16_be = function() {
        if (position + 2 > length) return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        buffer_poke(scratch, 1, buffer_u8, buffer_peek(buffer, position, buffer_u8));
        buffer_poke(scratch, 0, buffer_u8, buffer_peek(buffer, position + 1, buffer_u8));
        position += 2;
        return buffer_peek(scratch, 0, buffer_s16);
    };
    
    static __read_s32_be = function() {
        if (position + 4 > length) return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        buffer_poke(scratch, 3, buffer_u8, buffer_peek(buffer, position, buffer_u8));
        buffer_poke(scratch, 2, buffer_u8, buffer_peek(buffer, position + 1, buffer_u8));
        buffer_poke(scratch, 1, buffer_u8, buffer_peek(buffer, position + 2, buffer_u8));
        buffer_poke(scratch, 0, buffer_u8, buffer_peek(buffer, position + 3, buffer_u8));
        position += 4;
        return buffer_peek(scratch, 0, buffer_s32);
    };
    
    static __read_f32_be = function() {
        if (position + 4 > length) return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        buffer_poke(scratch, 3, buffer_u8, buffer_peek(buffer, position, buffer_u8));
        buffer_poke(scratch, 2, buffer_u8, buffer_peek(buffer, position + 1, buffer_u8));
        buffer_poke(scratch, 1, buffer_u8, buffer_peek(buffer, position + 2, buffer_u8));
        buffer_poke(scratch, 0, buffer_u8, buffer_peek(buffer, position + 3, buffer_u8));
        position += 4;
        return buffer_peek(scratch, 0, buffer_f32);
    };
    
    static __read_f64_be = function() {
        if (position + 8 > length) return __create_error(MSGPACK_ERROR_UNEXPECTED_END, position);
        buffer_poke(scratch, 7, buffer_u8, buffer_peek(buffer, position, buffer_u8));
        buffer_poke(scratch, 6, buffer_u8, buffer_peek(buffer, position + 1, buffer_u8));
        buffer_poke(scratch, 5, buffer_u8, buffer_peek(buffer, position + 2, buffer_u8));
        buffer_poke(scratch, 4, buffer_u8, buffer_peek(buffer, position + 3, buffer_u8));
        buffer_poke(scratch, 3, buffer_u8, buffer_peek(buffer, position + 4, buffer_u8));
        buffer_poke(scratch, 2, buffer_u8, buffer_peek(buffer, position + 5, buffer_u8));
        buffer_poke(scratch, 1, buffer_u8, buffer_peek(buffer, position + 6, buffer_u8));
        buffer_poke(scratch, 0, buffer_u8, buffer_peek(buffer, position + 7, buffer_u8));
        position += 8;
        return buffer_peek(scratch, 0, buffer_f64);
    };
    
    static __create_error = function(_message, _pos) {
        return {
            __msgpack_error: true,
            success: false,
            error: _message,
            position: _pos
        };
    };
}
