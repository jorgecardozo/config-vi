# Agregar la clase MouseMover
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class MouseMover {
    [DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
    public static extern bool SetCursorPos(int x, int y);

    [DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
    public static extern void mouse_event(int dwFlags, int dx, int dy, int cButtons, int dwExtraInfo);

    private const int MOUSEEVENTF_MOVE = 0x0001;

    public static void MoveMouse(int direction) {
        SetCursorPos(direction, 500); // Mueve el mouse en Y=500 para mantenerlo estable verticalmente
    }

    public static void ClickMouse() {
        mouse_event(MOUSEEVENTF_MOVE, 0, 0, 0, 0);
    }
}
"@

# Coordenadas iniciales para mover de izquierda a derecha
$leftPosition = 400
$rightPosition = 600
$direction = $leftPosition

# Función para simular una tecla Shift
function Press-Shift {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.SendKeys]::SendWait("+")
}

# Bucle principal: mueve el mouse y envía Shift cada 30 segundos
while ($true) {
    # Mueve el mouse de izquierda a derecha
    [MouseMover]::MoveMouse($direction)
    Write-Host "Mouse moved to X=$direction"

    # Alterna la dirección
    if ($direction -eq $leftPosition) {
        $direction = $rightPosition
    } else {
        $direction = $leftPosition
    }

    # Envía la tecla Shift cada 30 segundos
    Press-Shift
    Write-Host "Shift key sent to keep the system awake"

    # Espera 30 segundos antes de repetir
    Start-Sleep -Seconds 2
}