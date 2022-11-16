from nbformat import read
from nbclient import execute
import json

nb = read("ipywidgets.ipynb", 4)

with open('ipywidgets_executed.ipynb', 'w') as f:
    f.write(json.dumps(execute(nb, store_widget_state=True)))
