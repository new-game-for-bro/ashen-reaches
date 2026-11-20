# Ashen Reaches model world plan

Status: design and inventory only. The existing game still uses the cloister; the other zones and streaming are not implemented or verified. The layout is a concept, not a render of the actual models.

An inventory of all source GLBs ran in GitHub Actions. Counts below sum triangle-mode mesh primitives as stored in GLB metadata, without accounting for mesh instances or occlusion. All inspected files reported zero skins and animations. File size is compressed GLB size, not runtime memory. See `models/ATTRIBUTION.md` for source and licensing information.

| Source model | Proposed role | Triangles | GLB MB | Work needed |
| --- | --- | ---: | ---: | --- |
| ancient_corinth_-_peirene_fountain | Fountain Court arena | 70,042 | 14.8 | Calibrate scale and collision |
| cloister_of_cathedral_of_st._mary | Cloister Crypt and duel | 525,701 | 27.3 | Reduce mesh; replace flat collision |
| castle_grafenegg | Ashen Keep hub | 249,999 | 56.7 | Validate textures, scale, collision |
| saint_sarkis_church_-_khtzkonk_monastery | Hermit Monastery | 999,718 | 157.3 | Reduce mesh and textures; test mobile |
| great_mosque_at_kilwa_kisiwani | Sunken ruins | 387,857 | 82.0 | Respect source, simplify and test |
| holmfirth_town_centre_west_yorkshire | Holmfirth Hollow | 4,000,018 | 204.0 | Decimate, chunk, build proxy collision |
| canadian_city_downtown_photogrammetry_analysis | Rift District | 2,000,000 | 108.1 | Decimate, chunk, proxy collision |
| manhattan_bridge_brooklyn_new_york_ny_usa | Iron Span crossing | 1,404,978 | 217.2 | Decimate, chunk, proxy collision |
| ashen_dragon_relic_complete | Relic landmark | 91,564 | 30.9 | Determine shape and placement |
| death_reaper | Reaper encounter | 44,104 | 7.3 | Static model; rig/animate for combat |
| soul_harvester__the_twin_blades_reaper | Elite encounter | 1,127,038 | 98.3 | Reduce, rig and animate |
| verdant_reaper__the_green_harbinger | Elite encounter | 1,074,594 | 69.9 | Reduce, rig and animate |
| gtalc_2001_full-map_3dmodel | Candidate rift map | 1,169,865 | 106.4 | Verify third-party rights before public release; reduce and chunk |

The cloister appears twice in the repository because an importable copy was created outside the ignored library directory; it is one source asset. The proposed map puts these assets in separate locations rather than loading them simultaneously. Environment scans may contain their own ground and have different origins and scales. They require visual alignment and tailored collision before they can be playable. Large characters are not animated by their GLB files.

Implementation order: (1) profile the existing cloister on the target Android device; (2) build per-zone wrappers with measured bounds, spawn points and simple collision; (3) implement loading/unloading with mobile memory measurements; (4) optimize dense models and add them one region at a time; (5) rig character assets and validate animations; (6) verify rights and attribution before distribution. These steps are outstanding and no Android performance target has been validated.

To regenerate the measurements, run the **Inspect world models in cloud** GitHub Actions workflow. It downloads the private Git LFS models to an ephemeral runner and publishes the inventory as a private artifact; it does not render or modify the models.
