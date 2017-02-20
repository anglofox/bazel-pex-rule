import yaml

class Library:
    def __init__(self):
        self._one = yaml.load("""
            name: Vorlin Laruknuzum
            sex: Male
            class: Priest
            title: Acolyte
            hp: [32, 71]
            sp: [1, 13]
            gold: 423
            inventory:
                - a Holy Book of Prayers (Words of Wisdom)
                - an Azure Potion of Cure Light Wounds
                - a Silver Wand of Wonder
            """
        )

    @property
    def one(self):
        return self._one

