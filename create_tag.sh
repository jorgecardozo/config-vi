#!/bin/bash

# Colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# Función para mostrar el logo
show_logo() {
    echo -e "${RED}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║                      Santander Consumer                       ║"
    echo "║                  Sistema de Gestión de Tags                   ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Mostramos tags existentes
show_existing_tags() {
    echo -e "\n${BLUE}Tags existentes:${NC}"
    echo "------------------------------------------------"
    for tag in $(git tag -l | sort -V); do
        echo -e "${GREEN}$tag${NC}"
    done
    LATEST_TAG=$(git tag --sort=-v:refname | head -n1)
    if [ ! -z "$LATEST_TAG" ]; then
        echo -e "\n${GREEN}Último tag:${NC} $LATEST_TAG"
    else
        echo -e "\n${YELLOW}No hay tags en el repositorio${NC}"
    fi
}

# Mostramos los últimos commits
show_recent_commits() {
    echo -e "\n${BLUE}Últimos commits:${NC}"
    git log --oneline -n 5
}

# Validamos formato de versión
validate_version() {
    if [[ ! $1 =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-rc\.[0-9]+)?$ ]]; then
        echo -e "${RED}Error: El formato del tag debe ser v#.#.# o v#.#.#-rc.# (ejemplo: v1.0.0 o v1.0.0-rc.1)${NC}"
        exit 1
    fi
}

# Creamos nuevo tag
create_new_tag() {
    local NEW_TAG=$1
    local COMMIT_REF=$2
    local TAG_MESSAGE=$3

    echo -e "\n${YELLOW}Creando nuevo tag: ${NEW_TAG}${NC}"

    if [ -z "$TAG_MESSAGE" ]; then
        [ -z "$COMMIT_REF" ] && git tag "$NEW_TAG" 2>/dev/null || git tag "$NEW_TAG" "$COMMIT_REF" 2>/dev/null
    else
        [ -z "$COMMIT_REF" ] && git tag -a "$NEW_TAG" -m "$TAG_MESSAGE" 2>/dev/null || git tag -a "$NEW_TAG" "$COMMIT_REF" -m "$TAG_MESSAGE" 2>/dev/null
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Tag creado exitosamente${NC}"
        [ ! -z "$COMMIT_REF" ] && echo -e "Commit: $COMMIT_REF"
        [ ! -z "$TAG_MESSAGE" ] && echo -e "Mensaje: $TAG_MESSAGE"
    else
        echo -e "${RED}Error al crear el tag${NC}"
        exit 1
    fi
}

# Mostrar Logo
show_logo
show_existing_tags
show_recent_commits

CURRENT_VERSION=$(git tag --sort=-v:refname | head -n1)

if [ -z "$CURRENT_VERSION" ]; then
    echo -e "\n${YELLOW}No se encontraron tags. ¿Deseas crear el primer tag (v0.0.1)? [y/N]${NC}"
    read -n 1 -r RESPONSE
    echo
    if [[ $RESPONSE =~ ^[Yy]$ ]]; then
        create_new_tag "v0.0.1"
        exit 0
    fi
    CURRENT_VERSION="v0.0.0"
fi

validate_version "$CURRENT_VERSION"

VERSION_NUMBERS=${CURRENT_VERSION#v} # Quita la 'v'
VERSION_NUMBERS=${VERSION_NUMBERS%%-*} # Quita -rc.X si lo tiene
IFS='.' read -r VNUM1 VNUM2 VNUM3 <<< "$VERSION_NUMBERS"

echo -e "\n${BLUE}Versión actual: ${CURRENT_VERSION}${NC}"
echo -e "\nSelecciona una opción:"
echo "1) Incrementar versión mayor (Major) [$VNUM1 → $((VNUM1+1)).0.0]"
echo "2) Incrementar versión menor (Minor) [$VNUM1.$VNUM2 → $VNUM1.$((VNUM2+1)).0]"
echo "3) Incrementar parche (Patch) [$VNUM1.$VNUM2.$VNUM3 → $VNUM1.$VNUM2.$((VNUM3+1))]"
echo "4) Crear Release Candidate (RC) [$VNUM1.$VNUM2.$VNUM3 → $VNUM1.$VNUM2.$VNUM3-rc.X]"
echo "5) Ingresar versión manualmente"
echo "6) Salir"

read -n 1 -p "Opción (1-6): " OPTION
echo

case $OPTION in
    1) NEW_TAG="v$((VNUM1+1)).0.0" ;;
    2) NEW_TAG="v$VNUM1.$((VNUM2+1)).0" ;;
    3) NEW_TAG="v$VNUM1.$VNUM2.$((VNUM3+1))" ;;
    4)
        echo -n "Número de RC (ej: 1 para -rc.1): "
        read RC_NUM
        NEW_TAG="v$VNUM1.$VNUM2.$VNUM3-rc.$RC_NUM"
        ;;
    5)
        echo -n "Ingresa la nueva versión (formato v#.#.# o v#.#.#-rc.#): "
        read NEW_TAG
        validate_version "$NEW_TAG"
        ;;
    6)
        echo -e "${BLUE}Saliendo...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Opción inválida${NC}"
        exit 1
        ;;
esac

# Preguntar por commit específico
echo -e "\n${YELLOW}¿Deseas crear el tag en un commit específico? [y/N]${NC}"
read -n 1 -r COMMIT_RESPONSE
echo

COMMIT_REF=""
if [[ $COMMIT_RESPONSE =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Ingresa el hash del commit o referencia (ejemplo: abc1234 o HEAD~1):${NC}"
    read COMMIT_REF
fi

# Preguntar por mensaje
echo -e "\n${YELLOW}¿Deseas agregar una descripción al tag? [y/N]${NC}"
read -n 1 -r MESSAGE_RESPONSE
echo

TAG_MESSAGE=""
if [[ $MESSAGE_RESPONSE =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}Ingresa la descripción del tag:${NC}"
    read TAG_MESSAGE
fi

# Confirmación final
echo -e "\n${YELLOW}¿Confirmas crear el tag $NEW_TAG${COMMIT_REF:+ en commit $COMMIT_REF}${TAG_MESSAGE:+ con descripción}? [y/N]${NC}"
read -n 1 -r RESPONSE
echo

if [[ $RESPONSE =~ ^[Yy]$ ]]; then
    create_new_tag "$NEW_TAG" "$COMMIT_REF" "$TAG_MESSAGE"
    show_existing_tags

    # Preguntar si desea pushear el tag
    echo -e "\n${YELLOW}¿Deseas pushear el tag $NEW_TAG al repositorio remoto? [y/N]${NC}"
    read -n 1 -r PUSH_RESPONSE
    echo

    if [[ $PUSH_RESPONSE =~ ^[Yy]$ ]]; then
        git push origin "$NEW_TAG"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Tag pusheado correctamente a origin${NC}"
        else
            echo -e "${RED}Error al pushear el tag${NC}"
        fi
    fi

    # Preguntar si desea eliminar el tag
    echo -e "\n${YELLOW}¿Deseas eliminar el tag $NEW_TAG si fue un error? (Esto eliminará local y remoto) [y/N]${NC}"
    read -n 1 -r DELETE_RESPONSE
    echo

    if [[ $DELETE_RESPONSE =~ ^[Yy]$ ]]; then
        git tag -d "$NEW_TAG"
        git push origin ":refs/tags/$NEW_TAG"
        echo -e "${RED}Tag $NEW_TAG eliminado local y remotamente.${NC}"
    fi
else
    echo -e "${YELLOW}Operación cancelada${NC}"
fi