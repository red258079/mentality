import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.core.companies import find_company_by_name


def test_find_company_by_name_exact():
    comp = find_company_by_name("Samsung Electronics Thái Nguyên (SEVT)")
    assert comp is not None
    assert comp["id"] == "samsung_sevt_tn"
    assert comp["name"] == "Samsung Electronics Thái Nguyên (SEVT)"


def test_find_company_by_name_case_insensitive():
    comp_by_short = find_company_by_name("fpt software")
    assert comp_by_short is not None
    assert comp_by_short["id"] == "fpt_software_hl"

    comp_by_full = find_company_by_name("tổ hợp nhà máy vinfast hải phòng")
    assert comp_by_full is not None
    assert comp_by_full["id"] == "vinfast_hp"


def test_find_company_by_name_unknown():
    assert find_company_by_name("Công ty Không Tồn Tại XYZ") is None
    assert find_company_by_name("") is None
    assert find_company_by_name(None) is None


def test_find_company_by_name_custom():
    by_id = find_company_by_name("custom")
    assert by_id is not None
    assert by_id["id"] == "custom"
    assert by_id["workplace_type"] == "custom"
    assert by_id["latitude"] is None
    assert by_id["longitude"] is None

    by_short = find_company_by_name("Công ty khác")
    assert by_short is not None
    assert by_short["id"] == "custom"


class TestFindCompanyByName(unittest.TestCase):
    def test_exact(self):
        test_find_company_by_name_exact()

    def test_case_insensitive(self):
        test_find_company_by_name_case_insensitive()

    def test_unknown_name(self):
        test_find_company_by_name_unknown()

    def test_custom(self):
        test_find_company_by_name_custom()


if __name__ == "__main__":
    unittest.main()

