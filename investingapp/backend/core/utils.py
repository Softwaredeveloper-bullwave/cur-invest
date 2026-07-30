import re


def to_camel(snake_str: str) -> str:
    parts = snake_str.split('_')
    return parts[0] + ''.join(word.capitalize() for word in parts[1:])


def to_snake(camel_str: str) -> str:
    s1 = re.sub(r'(.)([A-Z][a-z]+)', r'\1_\2', camel_str)
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s1).lower()


def decamelize(data):
    if isinstance(data, dict):
        return {to_snake(k): decamelize(v) for k, v in data.items()}
    if isinstance(data, list):
        return [decamelize(item) for item in data]
    return data


def camelize(data):
    if isinstance(data, dict):
        return {to_camel(k): camelize(v) for k, v in data.items()}
    if isinstance(data, list):
        return [camelize(item) for item in data]
    return data
