from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "scripts" / "docx" / "preprocess.py"
SPEC = importlib.util.spec_from_file_location("docx_preprocess", MODULE_PATH)
assert SPEC and SPEC.loader
preprocess = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(preprocess)


class PreprocessTests(unittest.TestCase):
    def test_local_inputs_are_expanded_for_pandoc(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "sections").mkdir()
            (root / "main.tex").write_text(
                "Before.\n\\input{sections/detail}\nAfter.\n",
                encoding="utf-8",
            )
            (root / "sections" / "detail.tex").write_text(
                "Versioned detail.\n", encoding="utf-8"
            )

            result = preprocess.expand_inputs(root / "main.tex")

            self.assertIn("Before.", result)
            self.assertIn("Versioned detail.", result)
            self.assertIn("After.", result)
            self.assertNotIn(r"\input", result)

    def test_includes_can_be_resolved_from_a_resource_root(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source_dir = root / "documents" / "example"
            source_dir.mkdir(parents=True)
            (root / "shared").mkdir()
            source = source_dir / "example.tex"
            source.write_text(r"\include{shared/preface}", encoding="utf-8")
            (root / "shared" / "preface.tex").write_text(
                "Shared preface.", encoding="utf-8"
            )

            result = preprocess.expand_inputs(source, search_roots=(root,))

            self.assertEqual(result, "Shared preface.")

    def test_cyclic_includes_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "main.tex"
            source.write_text(r"\input{main}", encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "cyclic LaTeX include"):
                preprocess.expand_inputs(source)

    def test_image_count_is_derived_from_expanded_source(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "document.tex"
            source.write_text(
                "\\includegraphics{one.png}\n"
                "\\includegraphics[width=4cm]{two.jpg}\n",
                encoding="utf-8",
            )

            _, metadata = preprocess.prepare_source(source)

            self.assertEqual(metadata, {"images": 2})


if __name__ == "__main__":
    unittest.main()
