"""Meaningful failure fixtures and isolated batch/transition integration tests.

Run: python -m unittest discover -s tools/farming -p test_asset_pipeline.py -v
"""
import hashlib
import json
import io
from contextlib import redirect_stdout, redirect_stderr
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
from PIL import Image, ImageDraw
from asset_common import ROOT, components, load_palette, seamless_errors, pixels, protect_delivered
from build_art_handoff import build
from gen_asset_manifest import build_manifest, _status_for
from postprocess_assets import process
from qc_assets import check_image, inspect
from transition_assets import make_mask
import gen_phase00_textures as p0


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.directory = Path(self.temp.name)
        self.entry = {"type": "crop_stage", "size": [64, 64], "stage": "mature"}

    def tearDown(self):
        self.temp.cleanup()

    def sprite(self):
        image = Image.new("RGBA", (64, 64))
        ImageDraw.Draw(image).rectangle((20, 22, 43, 61), fill=(78, 123, 78, 255))
        return image

    def check(self, image):
        path = self.directory / "stage_3.png"
        image.save(path)
        return check_image(path, self.entry)

    def test_valid_sprite_and_failure_fixtures(self):
        self.assertEqual(self.check(self.sprite())[0], [])
        image = self.sprite().convert("RGB")
        self.assertTrue(any("mode" in e for e in self.check(image)[0]))
        image = self.sprite()
        image.putpixel((25, 25), (78, 123, 78, 120))
        self.assertIn("alpha must be binary 0/255", self.check(image)[0])
        image = self.sprite()
        image.putpixel((0, 0), (78, 123, 78, 255))
        errors = self.check(image)[0]
        self.assertTrue(any("safety" in e for e in errors))
        self.assertIn("disconnected foreground components", errors)
        self.assertIn("empty sprite", self.check(Image.new("RGBA", (64, 64)))[0])
        self.assertTrue(any("size" in e for e in self.check(self.sprite().resize((128,128)))[0]))

    def test_wrong_format_and_atlas_metadata(self):
        path = self.directory / "fake.png"
        self.sprite().convert("RGB").save(path, format="BMP")
        self.assertIn("format must be PNG", check_image(path, {"type":"ground", "size":[64,64]})[0])
        atlas = Image.new("RGBA", (1024,1024), (0,0,0,255))
        atlas.putpixel((1000,1000), (0,0,0,0))
        path = self.directory / "atlas.png"
        atlas.save(path)
        self.assertIn("bm=255 must be fully opaque", check_image(path, {"type":"atlas", "size":[1024,1024]})[0])
        meta = self.directory / "assets/farming/transitions/trans_upper_dirt.json"
        meta.parent.mkdir(parents=True)
        meta.write_text('{"bits":{},"tile":32}', encoding="utf-8")
        reports = inspect(self.directory, "transitions")
        self.assertTrue(any("metadata" in e for r in reports for e in r["errors"]))

    def test_seam_break_and_postprocess(self):
        image = Image.new("RGB", (128,128), (100,80,60))
        # A horizontal gradient whose wrap jump far exceeds interior gradients.
        px = image.load()
        for y in range(128):
            for x in range(128):
                px[x,y] = (x,x,x)
        self.assertTrue(seamless_errors(image))
        repaired = process(image, "ground")
        self.assertEqual(repaired.size, (64,64))
        self.assertEqual(seamless_errors(repaired), [])
        self.assertEqual(repaired.crop((0,0,1,64)).tobytes(), repaired.crop((63,0,64,64)).tobytes())

    def test_sprite_postprocess_and_rejected_inputs(self):
        image = self.sprite().resize((128,128), Image.Resampling.NEAREST)
        image.putpixel((2,2), (255,255,255,255))
        processed = process(image, "crop_stage")
        self.assertEqual(len(components(processed.getchannel("A"))), 1)
        self.assertEqual(processed.getchannel("A").getbbox(), (20,22,44,62))
        self.assertEqual(set(pixels(processed.getchannel("A"))), {0,255})
        with self.assertRaises(ValueError):
            process(Image.new("RGBA", (100,100)), "crop_stage")
        with self.assertRaises(ValueError):
            process(Image.new("RGB", (128,128)), "crop_stage")
        with self.assertRaises(ValueError):
            process(Image.new("RGBA", (128,128), (0,0,0,0)), "ground")
        with self.assertRaises(ValueError):
            process(Image.new("RGBA", (128,128)), "crop_stage")
        key = Image.new("RGB", (128,128), (255,0,255))
        ImageDraw.Draw(key).rectangle((40,40,85,110), fill=(78,123,78))
        self.assertTrue(process(key,"crop_stage",background="#ff00ff").getchannel("A").getbbox())

    def test_missing_and_extra_stage(self):
        results = inspect(self.directory, "crops")
        self.assertEqual(len(results), 10)
        self.assertTrue(all("missing required asset" in r["errors"] for r in results))
        path = self.directory / "assets/farming/crops/dew_grass/stage_99.png"
        path.parent.mkdir(parents=True)
        self.sprite().save(path)
        self.assertTrue(any("unexpected crop stage" in r["errors"] for r in inspect(self.directory, "crops")))

    def test_delivered_guard_and_missing_status_precedence(self):
        path = self.directory / "content/farming/art_status.json"
        path.parent.mkdir(parents=True)
        rel = "assets/farming/ground/ground_stone.png"
        path.write_text(json.dumps({rel:{"status":"delivered"}}),encoding="utf-8")
        with patch("asset_common.ROOT", self.directory):
            with self.assertRaises(ValueError):
                protect_delivered([rel])
            protect_delivered(["assets/farming/ground/ground_grass.png"])
        with patch("gen_asset_manifest.ROOT",str(self.directory)):
            self.assertEqual(_status_for(rel,{rel:{"status":"delivered"}})[0],"missing")

    def test_manifest_discovers_new_crop_from_baked_data(self):
        def source(name):
            if name == "terrains.json":
                return {"terrains":[]}
            return {"crops":[{"crop_id":"new_herb","name":"new herb","category":"herb","harvest_type":"remove",
                              "growth_stages":[{"id":"seed","sprite":"stage_0"},{"id":"mature","sprite":"stage_1"}]}]}
        with patch("gen_asset_manifest._load",side_effect=source):
            paths = [e["path"] for e in build_manifest()["assets"] if e["type"]=="crop_stage"]
        self.assertEqual(paths,["assets/farming/crops/new_herb/stage_0.png","assets/farming/crops/new_herb/stage_1.png"])

    def test_all_placeholder_cli_entrypoints_invoke_guard_before_writes(self):
        import gen_farm_terrains
        import gen_farm_crops
        for module, target in ((p0,"asset_common.protect_delivered"),
                               (gen_farm_terrains,"gen_farm_terrains.protect_delivered"),
                               (gen_farm_crops,"gen_farm_crops.protect_delivered")):
            with patch.object(sys,"argv",[module.__name__]), patch(target,side_effect=ValueError("blocked")) as guard:
                with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
                    module.main()
                guard.assert_called_once()

    def test_mask_defaults_match_all_256_existing_masks(self):
        config = load_palette()["transition"]
        for bm in range(256):
            self.assertEqual(make_mask(bm, config), p0._make_mask(bm))

    def test_handoff_and_batch_round_trip(self):
        package = self.directory / "handoff"
        build("ground", package)
        manifest = json.loads((package/"manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(len(manifest["assets"]), 4)
        raw = self.directory / "raw"
        for e in manifest["assets"]:
            path = raw / e["path"]
            path.parent.mkdir(parents=True, exist_ok=True)
            Image.new("RGB",(128,128),(121,160,92)).save(path)
        before = {p:hashlib.sha256(p.read_bytes()).hexdigest() for p in raw.rglob("*.png")}
        command = [sys.executable,str(ROOT/"tools/farming/postprocess_assets.py"),"--manifest",str(package/"manifest.json"),"--input",str(raw),"--output",str(self.directory/"processed")]
        result = subprocess.run(command, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(before, {p:hashlib.sha256(p.read_bytes()).hexdigest() for p in raw.rglob("*.png")})
        self.assertEqual(len(list((self.directory/"processed/previews").glob("*.png"))),4)
        self.assertNotEqual(subprocess.run(command,capture_output=True).returncode,0)
        with self.assertRaises(ValueError):
            build("ground",package)

    def test_transition_cli_preserves_ground_and_is_deterministic(self):
        grounds = list((ROOT/"assets/farming/ground").glob("*.png"))
        before = {p:hashlib.sha256(p.read_bytes()).hexdigest() for p in grounds}
        outputs = []
        for run in ("first","second"):
            output = self.directory/run
            result = subprocess.run([sys.executable,str(ROOT/"tools/farming/gen_farm_terrains.py"),"--transitions-only","--output-root",str(output)],capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            outputs.append({p.relative_to(output).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in output.rglob("*") if p.is_file()})
        self.assertEqual(outputs[0],outputs[1])
        self.assertEqual(len(outputs[0]),6)
        self.assertEqual(before,{p:hashlib.sha256(p.read_bytes()).hexdigest() for p in grounds})


if __name__ == "__main__":
    unittest.main()
