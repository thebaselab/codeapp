"""Test nbformat.validator"""

# Copyright (c) IPython Development Team.
# Distributed under the terms of the Modified BSD License.

import os
import re

from .base import TestsBase
from jsonschema import ValidationError
from nbformat import read
from ..validator import isvalid, validate, iter_validate
from ..json_compat import VALIDATORS

import pytest


# Fixtures
@pytest.fixture(autouse=True)
def clean_env_before_and_after_tests():
    """Fixture to clean up env variables before and after tests."""
    os.environ.pop("NBFORMAT_VALIDATOR", None)
    yield
    os.environ.pop("NBFORMAT_VALIDATOR", None)


# Helpers
def set_validator(validator_name):
    os.environ["NBFORMAT_VALIDATOR"] = validator_name


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_nb2(validator_name):
    """Test that a v2 notebook converted to current passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test2.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    validate(nb)
    assert isvalid(nb) == True


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_nb3(validator_name):
    """Test that a v3 notebook passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test3.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    validate(nb)
    assert isvalid(nb) == True


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_nb4(validator_name):
    """Test that a v4 notebook passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test4.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    validate(nb)
    assert isvalid(nb) == True


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_nb4_document_info(validator_name):
    """Test that a notebook with document_info passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test4docinfo.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    validate(nb)
    assert isvalid(nb)


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_nb4custom(validator_name):
    """Test that a notebook with a custom JSON mimetype passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test4custom.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    validate(nb)
    assert isvalid(nb)


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_nb4jupyter_metadata(validator_name):
    """Test that a notebook with a jupyter metadata passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test4jupyter_metadata.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    validate(nb)
    assert isvalid(nb)


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_nb4jupyter_metadata_timings(validator_name):
    """Tests that a notebook with "timing" in metadata passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test4jupyter_metadata_timings.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    validate(nb)
    assert isvalid(nb)


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_invalid(validator_name):
    """Test than an invalid notebook does not pass validation"""
    set_validator(validator_name)
    # this notebook has a few different errors:
    # - one cell is missing its source
    # - invalid cell type
    # - invalid output_type
    with TestsBase.fopen(u'invalid.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    with pytest.raises(ValidationError):
        validate(nb)
    assert not isvalid(nb)


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_validate_empty(validator_name):
    """Test that an empty notebook (invalid) fails validation"""
    set_validator(validator_name)
    with pytest.raises(ValidationError) as e:
        validate({})


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_future(validator_name):
    """Test that a notebook from the future with extra keys passes validation"""
    set_validator(validator_name)
    with TestsBase.fopen(u'test4plus.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    with pytest.raises(ValidationError):
        validate(nb, version=4, version_minor=3)

    assert not isvalid(nb, version=4, version_minor=3)
    assert isvalid(nb)


# This is only a valid test for the default validator, jsonschema
@pytest.mark.parametrize("validator_name", ["jsonschema"])
def test_validation_error(validator_name):
    set_validator(validator_name)
    with TestsBase.fopen(u'invalid.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    with pytest.raises(ValidationError) as exception_info:
        validate(nb)

    s = str(exception_info.value)
    assert re.compile(r"validating .required. in markdown_cell").search(s)
    assert re.compile(r"source.* is a required property").search(s)
    assert re.compile(r"On instance\[u?['\"].*cells['\"]\]\[0\]").search(s)
    assert len(s.splitlines()) < 10

# This is only a valid test for the default validator, jsonschema
@pytest.mark.parametrize("validator_name", ["jsonschema"])
def test_iter_validation_error(validator_name):
    set_validator(validator_name)
    with TestsBase.fopen(u'invalid.ipynb', u'r') as f:
        nb = read(f, as_version=4)

    errors = list(iter_validate(nb))
    assert len(errors) == 3
    assert {e.ref for e in errors} == {'markdown_cell', 'heading_cell', 'bad stream'}


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_iter_validation_empty(validator_name):
    """Test that an empty notebook (invalid) fails validation via iter_validate"""
    set_validator(validator_name)
    errors = list(iter_validate({}))
    assert len(errors) == 1
    assert type(errors[0]) == ValidationError


@pytest.mark.parametrize("validator_name", VALIDATORS)
def test_validation_no_version(validator_name):
    """Test that an invalid notebook with no version fails validation"""
    set_validator(validator_name)
    with pytest.raises(ValidationError) as e:
        validate({'invalid': 'notebook'})


def test_invalid_validator_raises_value_error():
    """Test that an invalid notebook with no version fails validation"""
    set_validator("foobar")
    with pytest.raises(ValueError):
        with TestsBase.fopen(u'test2.ipynb', u'r') as f:
            nb = read(f, as_version=4)


def test_invalid_validator_raises_value_error_after_read():
    """Test that an invalid notebook with no version fails validation"""
    set_validator("jsonschema")
    with TestsBase.fopen(u'test2.ipynb', u'r') as f:
        nb = read(f, as_version=4)

    set_validator("foobar")
    with pytest.raises(ValueError):
        validate(nb)


def test_fallback_validator_with_iter_errors_using_ref():
    """
    Test that when creating a standalone object (code_cell etc)
    the default validator is used as fallback.
    """
    import nbformat
    set_validator("fastjsonschema")
    nbformat.v4.new_code_cell()
    nbformat.v4.new_markdown_cell()
    nbformat.v4.new_raw_cell()


def test_non_unique_cell_ids():
    """Test than a non-unique cell id does not pass validation"""
    with TestsBase.fopen(u'invalid_unique_cell_id.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    # The read call corrects the error and only logs the validation issue, so we reapply the issue for the test after
    nb.cells[1].id = nb.cells[0].id
    with pytest.raises(ValidationError):
        validate(nb)
    # The validate call should have corrected the duplicate id entry
    assert isvalid(nb)
    # Reapply to id duplication issue
    nb.cells[1].id = nb.cells[0].id
    assert not isvalid(nb)


def test_invalid_cell_id():
    """Test than an invalid cell id does not pass validation"""
    with TestsBase.fopen(u'invalid_cell_id.ipynb', u'r') as f:
        nb = read(f, as_version=4)
    with pytest.raises(ValidationError):
        validate(nb)
    assert not isvalid(nb)
