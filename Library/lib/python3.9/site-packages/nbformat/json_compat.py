# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
"""
Common validator wrapper to provide a uniform usage of other schema validation
libraries.
"""

import os

import jsonschema
from jsonschema import Draft4Validator as _JsonSchemaValidator
from jsonschema import ValidationError

try:
    import fastjsonschema
    from fastjsonschema import JsonSchemaException as _JsonSchemaException
except ImportError:
    fastjsonschema = None
    _JsonSchemaException = ValidationError


class JsonSchemaValidator:
    name = "jsonschema"

    def __init__(self, schema):
        self._schema = schema
        self._default_validator = _JsonSchemaValidator(schema)  # Default
        self._validator = self._default_validator

    def validate(self, data):
        self._default_validator.validate(data)

    def iter_errors(self, data, schema=None):
        return self._default_validator.iter_errors(data, schema)


class FastJsonSchemaValidator(JsonSchemaValidator):
    name = "fastjsonschema"

    def __init__(self, schema):
        super().__init__(schema)
        self._validator = fastjsonschema.compile(schema)

    def validate(self, data):
        try:
            self._validator(data)
        except _JsonSchemaException as error:
            raise ValidationError(error.message, schema_path=error.path)

    def iter_errors(self, data, schema=None):
        if schema is not None:
            return self._default_validator.iter_errors(data, schema)

        errors = []
        validate_func = self._validator
        try:
            validate_func(data)
        except _JsonSchemaException as error:
            errors = [ValidationError(error.message, schema_path=error.path)]

        return errors


_VALIDATOR_MAP = [
    ("fastjsonschema", fastjsonschema, FastJsonSchemaValidator),
    ("jsonschema", jsonschema, JsonSchemaValidator),
]
VALIDATORS = [item[0] for item in _VALIDATOR_MAP]


def _validator_for_name(validator_name):
    if validator_name not in VALIDATORS:
        raise ValueError("Invalid validator '{0}' value!\nValid values are: {1}".format(
            validator_name, VALIDATORS))

    for (name, module, validator_cls) in _VALIDATOR_MAP:
        if module and validator_name == name:
            return validator_cls


def get_current_validator():
    """
    Return the default validator based on the value of an environment variable.
    """
    validator_name = os.environ.get("NBFORMAT_VALIDATOR", "jsonschema")
    return _validator_for_name(validator_name)
