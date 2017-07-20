from library import Library


class Binary:
    def __init__(self):
        self._lib = Library()

    def value(self):
        return self._lib.output
