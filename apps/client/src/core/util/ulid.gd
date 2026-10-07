# 仙途 · ULID 生成器
# 26 字符 Crockford Base32：10 字符毫秒时间戳（48bit）+ 16 字符随机（80bit）。
# 同一毫秒内低 16bit 计数器递增，保证字典序单调，可用于排序与主键。
class_name Ulid
extends RefCounted

const ALPHABET := "0123456789ABCDEFGHJKMNPQRSTVWXYZ"  # Crockford Base32（去除易混淆 I L O U）
const TOTAL_LEN := 26        # 总长度
const TIME_LEN := 10         # 时间戳字符数（48bit）
const RAND_LEN := 16         # 随机段字符数（80bit）
const MAX_COUNTER := 0xFFFF  # 同毫秒计数器上限

static var _last_ms: int = 0
static var _counter: int = 0
static var _rand_hi: int = 0     # 同毫秒内复用的 64bit 随机高段（保证字典序单调）


## 生成一个新的 ULID 字符串（大写 26 位）
static func new_id() -> String:
	var ms := int(Time.get_unix_time_from_system() * 1000.0)
	if ms <= _last_ms:
		ms = _last_ms
		_counter = (_counter + 1) & MAX_COUNTER
	else:
		_last_ms = ms
		_counter = randi() & MAX_COUNTER
		_rand_hi = (randi() << 32) | (randi() & 0xFFFFFFFF)
	return _encode_time(ms) + _encode_rand()


## 校验字符串是否为合法 ULID 格式
static func is_valid(p_id: String) -> bool:
	if p_id.length() != TOTAL_LEN:
		return false
	for i in range(TOTAL_LEN):
		if ALPHABET.find(p_id[i]) < 0:
			return false
	return true


## 48bit 时间戳编码为 10 字符
static func _encode_time(p_ms: int) -> String:
	var buf := PackedByteArray()
	buf.resize(6)
	for i in range(6):
		buf[5 - i] = (p_ms >> (8 * i)) & 0xFF
	return _encode_bytes(buf).substr(0, TIME_LEN)


## 80bit 随机段编码为 16 字符：64bit 随机 + 16bit 单调计数器
static func _encode_rand() -> String:
	var buf := PackedByteArray([
		(_rand_hi >> 56) & 0xFF, (_rand_hi >> 48) & 0xFF, (_rand_hi >> 40) & 0xFF, (_rand_hi >> 32) & 0xFF,
		(_rand_hi >> 24) & 0xFF, (_rand_hi >> 16) & 0xFF, (_rand_hi >> 8) & 0xFF, _rand_hi & 0xFF,
		(_counter >> 8) & 0xFF, _counter & 0xFF,
	])
	return _encode_bytes(buf)


## 字节流按 5bit 一组输出 Base32 字符；不足 5bit 的尾部左移补零凑足（保证输出 ceil(bits/5) 字符）
static func _encode_bytes(p_buf: PackedByteArray) -> String:
	var out := ""
	var acc := 0
	var bits := 0
	for b: int in p_buf:
		acc = (acc << 8) | (b & 0xFF)
		bits += 8
		while bits >= 5:
			bits -= 5
			out += ALPHABET[(acc >> bits) & 0x1F]
	if bits > 0:
		out += ALPHABET[(acc << (5 - bits)) & 0x1F]
	return out
