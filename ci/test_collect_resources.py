import importlib.util
import unittest
from pathlib import Path


spec = importlib.util.spec_from_file_location(
    "collect_resources", Path(__file__).with_name("collect-resources.py"))
collector = importlib.util.module_from_spec(spec)
spec.loader.exec_module(collector)


def unit(name, state="routed", value=10):
    return dict(compute_unit=name, design_state=state,
                LUT=value, REG=value, BRAM=value, DSP=0, URAM=0)


class CoreResourcesTests(unittest.TestCase):
    def test_only_routed_auroraflow_instances_are_counted(self):
        report = {"0": {"system diagram compute units": [
            unit("aurora_flow_0"), unit("aurora_flow_1", value=12),
            unit("aurora_flow_0", "synthesized", 100),
            unit("clock_bridge_0", value=1000), unit("send_0", value=1000),
        ]}}
        result = collector.core_resources(report)
        self.assertEqual([core["name"] for core in result["cores"]],
                         ["aurora_flow_0", "aurora_flow_1"])
        self.assertEqual([core["resources"]["LUT"] for core in result["cores"]],
                         [10, 12])

    def test_missing_core_cannot_be_reported_as_zero_utilization(self):
        with self.assertRaises(ValueError):
            collector.core_resources({"0": {"system diagram compute units": [unit("aurora_flow_0")]}})

    def test_duplicate_core_cannot_be_double_counted(self):
        with self.assertRaises(ValueError):
            collector.core_resources({"0": {"system diagram compute units": [
                unit("aurora_flow_0"), unit("aurora_flow_1"), unit("aurora_flow_1"),
            ]}})

    def test_appended_reports_cannot_reuse_stale_measurements(self):
        with self.assertRaises(ValueError):
            collector.core_resources({"0": {}, "1": {}})


if __name__ == "__main__":
    unittest.main()
