class_name FirestoreCodec
extends RefCounted


static func encode_fields(data: Dictionary) -> Dictionary:
	var fields := {}
	for key in data.keys():
		fields[key] = encode_value(data[key])
	return {"fields": fields}


static func encode_value(value: Variant) -> Dictionary:
	match typeof(value):
		TYPE_STRING:
			return {"stringValue": value}
		TYPE_BOOL:
			return {"booleanValue": value}
		TYPE_INT:
			return {"integerValue": str(value)}
		TYPE_FLOAT:
			return {"doubleValue": value}
		TYPE_DICTIONARY:
			return {"mapValue": encode_fields(value)}
		TYPE_ARRAY:
			var encoded_values := []
			for item in value:
				encoded_values.append(encode_value(item))
			return {"arrayValue": {"values": encoded_values}}
		_:
			return {"nullValue": null}


static func decode_fields(document: Dictionary) -> Dictionary:
	var result := {}
	var fields: Dictionary = document.get("fields", {})
	for key in fields.keys():
		result[key] = decode_value(fields[key])
	return result


static func decode_value(value: Dictionary) -> Variant:
	if value.has("stringValue"):
		return value["stringValue"]
	if value.has("booleanValue"):
		return value["booleanValue"]
	if value.has("integerValue"):
		return int(value["integerValue"])
	if value.has("doubleValue"):
		return value["doubleValue"]
	if value.has("mapValue"):
		return decode_fields(value["mapValue"])
	if value.has("arrayValue"):
		var decoded_values := []
		for item in value["arrayValue"].get("values", []):
			decoded_values.append(decode_value(item))
		return decoded_values
	return null
