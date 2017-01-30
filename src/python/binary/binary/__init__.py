from library import Library

class Binary:
    def __init__(self):
        self._lib = Library()

    def render(self):
        return self._lib.yaml()

    def value(self):
        return self._lib.one
