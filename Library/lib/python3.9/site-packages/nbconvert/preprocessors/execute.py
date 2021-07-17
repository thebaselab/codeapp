"""Module containing a preprocessor that executes the code cells
and updates outputs"""

# Copyright (c) IPython Development Team.
# Distributed under the terms of the Modified BSD License.
from typing import Optional
from nbformat import NotebookNode
from nbclient import NotebookClient, execute as _execute
from nbclient.util import run_sync
# Backwards compatability for imported name
from nbclient.exceptions import CellExecutionError

from .base import Preprocessor


def executenb(*args, **kwargs):
    from warnings import warn
    warn("The 'nbconvert.preprocessors.execute.executenb' function was moved to nbclient.execute. "
        "We recommend importing that library directly.",
        FutureWarning)
    return _execute(*args, **kwargs)


# We inherit from both classes to allow for traitlets to resolve as they did pre-6.0.
# This unfortunatley makes for some ugliness around initialization as NotebookClient
# assumes it's a constructed class with a nb object that we have to hack around.
class ExecutePreprocessor(Preprocessor, NotebookClient):
    """
    Executes all the cells in a notebook
    """

    def __init__(self, **kw):
        nb = kw.get('nb')
        Preprocessor.__init__(self, nb=nb, **kw)
        NotebookClient.__init__(self, nb, **kw)

    def _check_assign_resources(self, resources):
        if resources or not hasattr(self, 'resources'):
            self.resources = resources

    def preprocess(self, nb, resources=None, km=None):
        """
        Preprocess notebook executing each code cell.

        The input argument *nb* is modified in-place.

        Note that this function recalls NotebookClient.__init__, which may look wrong.
        However since the preprocess call acts line an init on exeuction state it's expected.
        Therefore, we need to capture it here again to properly reset because traitlet 
        assignments are not passed. There is a risk if traitlets apply any side effects for
        dual init.
        The risk should be manageable, and this approach minimizes side-effects relative
        to other alternatives.

        One alternative but rejected implementation would be to copy the client's init internals
        which has already gotten out of sync with nbclient 0.5 release before nbcovnert 6.0 released.

        Parameters
        ----------
        nb : NotebookNode
            Notebook being executed.
        resources : dictionary (optional)
            Additional resources used in the conversion process. For example,
            passing ``{'metadata': {'path': run_path}}`` sets the
            execution path to ``run_path``.
        km: KernelManager (optional)
            Optional kernel manager. If none is provided, a kernel manager will
            be created.

        Returns
        -------
        nb : NotebookNode
            The executed notebook.
        resources : dictionary
            Additional resources used in the conversion process.
        """
        NotebookClient.__init__(self, nb, km)
        self._check_assign_resources(resources)
        self.execute()
        return self.nb, self.resources

    async def async_execute_cell(
            self,
            cell: NotebookNode,
            cell_index: int,
            execution_count: Optional[int] = None,
            store_history: bool = False) -> NotebookNode:
        """
        Executes a single code cell.

        Overwrites NotebookClient's version of this method to allow for preprocess_cell calls.

        Parameters
        ----------
        cell : nbformat.NotebookNode
            The cell which is currently being processed.
        cell_index : int
            The position of the cell within the notebook object.
        execution_count : int
            The execution count to be assigned to the cell (default: Use kernel response)
        store_history : bool
            Determines if history should be stored in the kernel (default: False).
            Specific to ipython kernels, which can store command histories.

        Returns
        -------
        output : dict
            The execution output payload (or None for no output).

        Raises
        ------
        CellExecutionError
            If execution failed and should raise an exception, this will be raised
            with defaults about the failure.

        Returns
        -------
        cell : NotebookNode
            The cell which was just processed.
        """
        # Copied and intercepted to allow for custom preprocess_cell contracts to be fullfilled
        self.store_history = store_history
        cell, resources = self.preprocess_cell(cell, self.resources, cell_index)
        # Apply rules from nbclient for where to apply execution counts
        if execution_count and cell.cell_type == 'code' and cell.source.strip():
            cell['execution_count'] = execution_count
        return cell, resources

    def preprocess_cell(self, cell, resources, index, **kwargs):
        """
        Override if you want to apply some preprocessing to each cell.
        Must return modified cell and resource dictionary.

        Parameters
        ----------
        cell : NotebookNode cell
            Notebook cell being processed
        resources : dictionary
            Additional resources used in the conversion process.  Allows
            preprocessors to pass variables into the Jinja engine.
        index : int
            Index of the cell being processed
        """
        self._check_assign_resources(resources)
        # Because nbclient is an async library, we need to wrap the parent async call to generate a syncronous version.
        cell = run_sync(NotebookClient.async_execute_cell)(self, cell, index, store_history=self.store_history)
        return cell, self.resources
