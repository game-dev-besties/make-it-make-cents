from __future__ import annotations

import unittest

from tools.audit_dialogue import audit_episode


class DialogueAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.report = audit_episode(
            "dad",
            expected_phrase_lines=5,
        )

    def test_enumerates_every_reachable_selection_and_state(self) -> None:
        self.assertEqual(
            [len(question["cases"]) for question in self.report["questions"]],
            [32, 16, 128, 32],
        )
        self.assertGreater(self.report["summary"]["raw_paths"], 2_000_000)
        self.assertGreater(
            self.report["summary"]["final_mechanical_states"],
            1_000,
        )
        self.assertEqual(
            self.report["summary"]["reachable_deliveries"],
            ["normal", "silence"],
        )

    def test_surfaces_known_dad_interview_blind_spots(self) -> None:
        findings = {
            (finding["code"], finding.get("line_id"))
            for finding in self.report["findings"]
        }
        self.assertIn(("PHRASE_LINE_COUNT", None), findings)
        self.assertIn(("DEFAULT_FALLS_THROUGH", "dad_L002"), findings)
        self.assertIn(("DEFAULT_FALLS_THROUGH", "dad_L003"), findings)
        self.assertIn(("DEFAULT_FALLS_THROUGH", "dad_L004"), findings)
        self.assertIn(("UNREACHABLE_DELIVERY", "dad_L001"), findings)
        self.assertNotIn(("POSITIVE_OUTCOME_LOW_SUCCESS", None), findings)
        self.assertIn(("NEGATIVE_OUTCOME_HIGH_SUCCESS", None), findings)
        got_job = next(
            check
            for check in self.report["checks"]
            if check["branch"] == "dad_got_the_job"
        )
        self.assertEqual(got_job["success_range"]["min"], 5)

    def test_reports_word_budget_pressure(self) -> None:
        pressure = self.report["budget_pressure"]
        self.assertEqual(pressure["initial_budget"], 40)
        self.assertEqual(pressure["implemented_full_cost"], 48)
        self.assertEqual(pressure["headroom_over_all_full"], -8)
        self.assertEqual(
            pressure["full_cost_by_line"],
            {
                "dad_L001": 10,
                "dad_L002": 14,
                "dad_L003": 15,
                "dad_L004": 9,
            },
        )

    def test_hypothetical_budget_does_not_edit_episode_resource(self) -> None:
        hypothetical = audit_episode(
            "dad",
            initial_budget_override=0,
        )
        self.assertIn(
            "sponsor",
            hypothetical["summary"]["reachable_deliveries"],
        )
        self.assertEqual(hypothetical["assumptions"]["initial_budget"], 0)
        self.assertEqual(self.report["assumptions"]["initial_budget"], 40)


if __name__ == "__main__":
    unittest.main()
