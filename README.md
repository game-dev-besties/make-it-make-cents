# GMTK 2026 Project

## Setup Notes:

Clone this repository:

```bash
git clone https://github.com/game-dev-besties/legendary-disco.git
cd legendary-disco
```

Download [Godot 4.7.1](https://godotengine.org/download/archive/). The [Godot Introduction](https://docs.godotengine.org/en/stable/getting_started/introduction/) is a good place to get started / get a refresher.

## Tooling

If you want to test web export (what people will see when we actually upload the game to itch), you can run the following:

NOTE: you will need to install Web export templates before doing this, there are some instructions on how to do that in the [Godot documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html#export-templates). You should be able to get away with just selecting the "Web - Single Threaded" template.

```bash
./scripts/build-web.sh
python3 -m http.server 8000 --directory build/web
```
And then you should be able to view the game at `http://localhost:8000` (http://localhost:8000) in the browser.

If port 8000 is busy (i.e you get error `Address already in use`), you can use another port, such as:

```bash
python3 -m http.server 8011 --directory build/web
```

And you should be able to view it from a different port (swap out the numbers)

