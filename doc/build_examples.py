import os, random, shutil

# -- UTILS -------------------------------------------------------------------

def add_file(filepath):
    size = random.randint(30 * 1024 * 1024, 100 * 1024 * 1024)
    with open(filepath, "wb") as f:
        f.truncate(size)

# -- RENDER ------------------------------------------------------------------

RENDER_DIR = "render"
RENDER_AOV = {
    "beauty",
    "diffuse",
    "indirect",
    "emission",
    "Z",
    "P",
    "UV",
    "albedo",
}

RENDER_NAME = "lgt-base-v012-{AOV}-aces.{SEQ}.exr"

RENDER_FRAMERANGE = range(1001, 1061)

RENDER_MISSING_IMG = [
    {"aov": "beauty", "frame": 1050},
]

def do_render():
    if os.path.exists(RENDER_DIR):
        shutil.rmtree(RENDER_DIR)

    os.makedirs(RENDER_DIR)
    for aov in RENDER_AOV:
        aov_dir = os.path.join(RENDER_DIR, aov)
        os.makedirs(aov_dir)

        for i in RENDER_FRAMERANGE:
            img_name = RENDER_NAME.format(AOV=aov, SEQ=str(i).zfill(4))
            img_path = os.path.join(aov_dir, img_name)

            is_missing = any(
                aov == m["aov"] and i == m["frame"] for m in RENDER_MISSING_IMG
            )
            if not is_missing:
                add_file(img_path)


# -- CAMERA ------------------------------------------------------------------

CAMERA_DIR = "camera"
CAMERA_NAME_VERSION = "camera-{VARIANT}-v{VERSION}.{FORMAT}"
CAMERA_NAME_LAST    = "camera-{VARIANT}-last.{FORMAT}"

CAMERA_VERSION = range(1, 11)

CAMERA_VARIANT = {"base", "retime"}
CAMERA_FORMAT = {"usd",}

def do_camera():
    if os.path.exists(CAMERA_DIR):
        shutil.rmtree(CAMERA_DIR)
    os.makedirs(CAMERA_DIR)

    for variant in CAMERA_VARIANT:
        for format in CAMERA_FORMAT:
            cam_path = ""
            for v in CAMERA_VERSION:
                cam_name = CAMERA_NAME_VERSION.format(
                    VARIANT=variant,
                    VERSION=str(v).zfill(3),
                    FORMAT=format,
                )
                cam_path = os.path.join(CAMERA_DIR, cam_name)
                add_file(cam_path)
            cam_last = CAMERA_NAME_LAST.format(VARIANT=variant, FORMAT=format)
            cam_last_path = os.path.join(CAMERA_DIR, cam_last)
            os.symlink(cam_path, cam_last_path)

# -- SCENE -------------------------------------------------------------------

SCENE_DIR = "scene"
SCENE_NAME = "SEQ01-SHOT10-anim-{VARIANT}-v{VERSION}.ma"
SCENE_VARIANT = {
    "block": 11,
    "base": 5,
    "fix": 28,
    "delivery": 8,
}

def do_scene():
    if os.path.exists(SCENE_DIR):
        shutil.rmtree(SCENE_DIR)
    os.makedirs(SCENE_DIR)
    for variant, maxversion in SCENE_VARIANT.items():
        for i in range(1, maxversion):
            scene_name = SCENE_NAME.format(VARIANT=variant, VERSION=str(i).zfill(3))
            scene_path = os.path.join(SCENE_DIR, scene_name)
            add_file(scene_path)

# -- MAIN --------------------------------------------------------------------

def main(): 
    do_render()
    do_camera()
    do_scene()

main()
