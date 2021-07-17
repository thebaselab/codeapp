"""
Module with tests for exporter.py
"""

#-----------------------------------------------------------------------------
# Copyright (c) 2013, the IPython Development Team.
#
# Distributed under the terms of the Modified BSD License.
#
# The full license is in the file COPYING.txt, distributed with this software.
#-----------------------------------------------------------------------------

#-----------------------------------------------------------------------------
# Imports
#-----------------------------------------------------------------------------

from traitlets.config import Config

from .base import ExportersTestsBase
from ...preprocessors.base import Preprocessor
from ..exporter import Exporter
from ..base import get_export_names, ExporterDisabledError


#-----------------------------------------------------------------------------
# Class
#-----------------------------------------------------------------------------

class PizzaPreprocessor(Preprocessor):
    """Simple preprocessor that adds a 'pizza' entry to the NotebookNode.  Used 
    to test Exporter.
    """

    def preprocess(self, nb, resources):
        nb['pizza'] = 'cheese'
        return nb, resources


class TestExporter(ExportersTestsBase):
    """Contains test functions for exporter.py"""


    def test_constructor(self):
        """Can an Exporter be constructed?"""
        Exporter()


    def test_export(self):
        """Can an Exporter export something?"""
        exporter = Exporter()
        (notebook, resources) = exporter.from_filename(self._get_notebook())
        assert isinstance(notebook, dict)


    def test_preprocessor(self):
        """Do preprocessors work?"""
        config = Config({'Exporter': {'preprocessors': [PizzaPreprocessor()]}})
        exporter = Exporter(config=config)
        (notebook, resources) = exporter.from_filename(self._get_notebook())
        self.assertEqual(notebook['pizza'], 'cheese')

    def test_get_export_names_disable(self):
        """Can we disable a specific importer?"""
        config = Config({'Exporter': {'enabled': False}})
        export_names = get_export_names()
        self.assertFalse('Exporter' in export_names)

    def test_get_export_names_disable(self):
        """Can we disable all exporters then enable a single one"""
        config = Config({
            'Exporter': {'enabled': False}, 
            'NotebookExporter': {'enabled': True}
        })
        export_names = get_export_names(config=config)
        self.assertEqual(export_names, ['notebook'])
