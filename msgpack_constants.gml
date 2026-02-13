#macro MSGPACK_ERROR_INVALID_TYPE  "Invalid MessagePack type marker"
#macro MSGPACK_ERROR_UNEXPECTED_END "Unexpected end of buffer"
#macro MSGPACK_ERROR_INVALID_UTF8   "Invalid UTF-8 sequence"
#macro MSGPACK_ERROR_KEY_NOT_STRING "Map keys must be strings"
#macro MSGPACK_ERROR_UNSUPPORTED_EXT "Unsupported extension type"
#macro MSGPACK_ERROR_INVALID_LENGTH "Invalid length field"

#macro MSGPACK_EXT_STRUCT_KEY_TYPE "__msgpack_ext_type"
#macro MSGPACK_EXT_STRUCT_KEY_DATA "__msgpack_ext_data"

// Format constants
#macro MSGPACK_NIL          0xc0
#macro MSGPACK_FALSE        0xc2
#macro MSGPACK_TRUE         0xc3
#macro MSGPACK_BIN8         0xc4
#macro MSGPACK_BIN16        0xc5
#macro MSGPACK_BIN32        0xc6
#macro MSGPACK_EXT8         0xc7
#macro MSGPACK_EXT16        0xc8
#macro MSGPACK_EXT32        0xc9
#macro MSGPACK_FLOAT32      0xca
#macro MSGPACK_FLOAT64      0xcb
#macro MSGPACK_UINT8        0xcc
#macro MSGPACK_UINT16       0xcd
#macro MSGPACK_UINT32       0xce
#macro MSGPACK_UINT64       0xcf
#macro MSGPACK_INT8         0xd0
#macro MSGPACK_INT16        0xd1
#macro MSGPACK_INT32        0xd2
#macro MSGPACK_INT64        0xd3
#macro MSGPACK_FIXEXT1      0xd4
#macro MSGPACK_FIXEXT2      0xd5
#macro MSGPACK_FIXEXT4      0xd6
#macro MSGPACK_FIXEXT8      0xd7
#macro MSGPACK_FIXEXT16     0xd8
#macro MSGPACK_STR8         0xd9
#macro MSGPACK_STR16        0xda
#macro MSGPACK_STR32        0xdb
#macro MSGPACK_ARRAY16      0xdc
#macro MSGPACK_ARRAY32      0xdd
#macro MSGPACK_MAP16        0xde
#macro MSGPACK_MAP32        0xdf
