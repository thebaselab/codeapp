"""Export to PDF via a headless browser"""

# Copyright (c) IPython Development Team.
# Distributed under the terms of the Modified BSD License.

import asyncio

from traitlets import Bool
from .html import HTMLExporter

class WebPDFExporter(HTMLExporter):
    """Writer designed to write to PDF files.

    This inherits from :class:`HTMLExporter`. It creates the HTML using the
    template machinery, and then run pyppeteer to create a pdf.
    """
    export_from_notebook = "PDF via pyppeteer"

    allow_chromium_download = Bool(False,
        help='Whether to allow downloading Chromium if no suitable version is found on the system.'
    ).tag(config=True)

    def _check_launch_reqs(self):
        try:
            from pyppeteer import launch
            from pyppeteer.util import check_chromium
        except ModuleNotFoundError as e:
            raise RuntimeError("Pyppeteer is not installed to support Web PDF conversion. "
                               "Please install `nbconvert[webpdf]` to enable.") from e
        if not self.allow_chromium_download and not check_chromium():
            raise RuntimeError("No suitable chromium executable found on the system. "
                               "Please use '--allow-chromium-download' to allow downloading one.")
        return launch

    def run_pyppeteer(self, html):
        """Run pyppeteer."""

        async def main():
            browser = await self._check_launch_reqs()()
            page = await browser.newPage()
            await page.goto('data:text/html,'+html, waitUntil='networkidle2')

            dimensions = await page.evaluate(
              """() => {
                return {
                  width: document.body.scrollWidth,
                  height: document.body.scrollHeight,
                }
              }"""
            )
            width = dimensions['width']
            height = dimensions['height']

            pdf_data = await page.pdf(
              {
                'width': width,
                # 200 inches is the maximum height for Adobe Acrobat Reader.
                'height': min(height, 200 * 72),
                'printBackground': True,
                'margin': {
                  'left': '0px',
                  'right': '0px',
                  'top': '0px',
                  'bottom': '0px',
                 },
              }
            )
            await browser.close()
            return pdf_data

        pdf_data = asyncio.get_event_loop().run_until_complete(main())
        return pdf_data

    def from_notebook_node(self, nb, resources=None, **kw):
        self._check_launch_reqs()
        html, resources = super().from_notebook_node(
            nb, resources=resources, **kw
        )

        self.log.info('Building PDF')
        pdf_data = self.run_pyppeteer(html)
        self.log.info('PDF successfully created')

        # convert output extension to pdf
        # the writer above required it to be html
        resources['output_extension'] = '.pdf'

        return pdf_data, resources
