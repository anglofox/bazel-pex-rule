import yaml


class Library:
    def __init__(self):
        self._output = yaml.load("""
            name: Konstantin Itskov
            company: FINDMINE Inc.
            title: Co-founder & Chief Technical Officer
            Values:
                - Don't put off until tomorrow what you can do today.
                - Any fool can know, the point is to understand.
                - If you will it, it is no dream; and if you do not will it, a dream it is and a dream it will stay.
            """)

    @property
    def output(self):
        return self._output
