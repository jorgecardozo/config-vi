#!/bin/bash

# Directorio base donde están tus proyectos

DEV_DIR="/home/jcardozo/development"
LAYOUT_FILE="$HOME/.config/zellij/layouts/work_dev_auto.kdl"

# Crear el directorio si no existe

mkdir -p "$(dirname “$LAYOUT_FILE”)"

# Generar el layout

cat >"$LAYOUT_FILE" <<"EOF"
layout {
default_tab_template {
pane size=1 borderless=true {
plugin location="zellij:tab-bar"
}
children
pane size=1 borderless=true {
plugin location="zellij:status-bar"
}
}

EOF

# Buscar todos los directorios en /development que contengan package.json

for project_dir in "$DEV_DIR"/*/; do
  if [[ -f "$project_dir/package.json" ]]; then
    project_name=$(basename "$project_dir")

    # Generar tab para cada proyecto
    cat >>"$LAYOUT_FILE" <<EOF


tab name="$project_name" {
pane split_direction="vertical" {
pane name="CODE" {
command "nvim"
cwd "$project_dir"
}


  pane split_direction="horizontal" {
    pane name="GIT" {
      cwd "$project_dir"
    }
    pane name="SERVER" {
      cwd "$project_dir"
    }
  }
}

}

EOF
  fi
done

# Cerrar el layout

echo "}" >>"$LAYOUT_FILE"

# Dar permisos como los otros layouts (rwxr-xr-x)

chmod 755 "$LAYOUT_FILE"

echo "✅ Layout generado en: $LAYOUT_FILE"
echo "🚀 Úsalo con: zellij -l work_dev_auto"

# Abrir automaticamente el layout
exec zellij -l work_dev_auto
