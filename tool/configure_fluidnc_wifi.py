#!/usr/bin/env python3
"""
configure_fluidnc_wifi.py
Configure automatiquement le WiFi de l'ESP32 FluidNC pour rejoindre le hotspot du PC.

Paramètres appliqués :
  - WiFi Mode : STA (Station client)
  - SSID      : Professeur20
  - Password  : 00000000
  - IP Mode   : Static (192.168.137.100)
  - Gateway   : 192.168.137.1
  - Netmask   : 255.255.255.0
"""

import sys
import time

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("[ERREUR] pyserial n'est pas installe. Installez-le avec : pip install pyserial")
    sys.exit(1)


def find_esp32_port(wait_seconds=10):
    """Recherche un port série USB (exclut le Bluetooth). Attend si nécessaire."""
    start = time.time()
    first_pass = True
    
    while True:
        ports = list(serial.tools.list_ports.comports())
        # Recherche prioritaire : puces USB-Série classiques
        for p in ports:
            desc = (p.description or "").lower()
            if any(k in desc for k in ["cp210", "ch340", "ch341", "usb-serial", "uart", "usb serial"]):
                return p.device, p.description
        
        # Recherche secondaire : tout port non-Bluetooth
        for p in ports:
            desc = (p.description or "").lower()
            if "bluetooth" not in desc and "bth" not in desc:
                return p.device, p.description

        if first_pass:
            print("[FluidNC] En attente du branchement du cable USB de l'ESP32...")
            first_pass = False

        if time.time() - start > wait_seconds:
            break
        time.sleep(1)

    return None, None


def configure_fluidnc(port_name, baudrate=115200, static_ip=True):
    print(f"\n[FluidNC] Connexion a {port_name} a {baudrate} bauds...")
    try:
        ser = serial.Serial(port_name, baudrate=baudrate, timeout=2)
    except Exception as e:
        print(f"[ERREUR] Impossible d'ouvrir {port_name} : {e}")
        return False

    time.sleep(1)
    ser.reset_input_buffer()

    # Réveiller la console FluidNC
    ser.write(b"\r\n")
    time.sleep(0.5)
    while ser.in_waiting:
        ser.readline()

    commands = [
        "$WiFi/Mode=STA",
        "$Sta/SSID=Professeur20",
        "$Sta/Password=00000000",
    ]

    if static_ip:
        commands.extend([
            "$Sta/IPMode=Static",
            "$Sta/IP=192.168.137.100",
            "$Sta/Gateway=192.168.137.1",
            "$Sta/Netmask=255.255.255.0",
        ])
    else:
        commands.append("$Sta/IPMode=DHCP")

    commands.append("$Bye")  # Redémarre l'ESP32 pour appliquer

    print("[FluidNC] Envoi des commandes de configuration WiFi :")
    for cmd in commands:
        line = f"{cmd}\r\n"
        print(f"  -> {cmd}")
        ser.write(line.encode("utf-8"))
        time.sleep(0.3)
        while ser.in_waiting:
            resp = ser.readline().decode("utf-8", errors="replace").strip()
            if resp:
                print(f"     <- {resp}")

    print("\n[FluidNC] Redemarrage en cours... Ecoute du demarrage (10s) :")
    start = time.time()
    got_ip = False
    while time.time() - start < 10:
        if ser.in_waiting:
            line = ser.readline().decode("utf-8", errors="replace").strip()
            if line:
                print(f"  [ESP32] {line}")
                if "192.168.137.100" in line or "Connected" in line:
                    got_ip = True
        time.sleep(0.05)

    ser.close()

    if got_ip:
        print("\n[SUCCES] L'ESP32 s'est connecte avec succes au hotspot Professeur20 !")
        print("         Vous pouvez ouvrir : http://192.168.137.100")
    else:
        print("\n[INFO] Configuration enregistree. Verifiez si http://192.168.137.100 repond dans votre navigateur.")
    return True


if __name__ == "__main__":
    if len(sys.argv) > 1:
        port = sys.argv[1]
    else:
        port, desc = find_esp32_port(wait_seconds=12)

    if not port:
        print("\n[ERREUR] Aucun ESP32 detecte sur le port USB.")
        print("         Veuillez brancher le cable USB de l'ESP32 sur le PC et relancer :")
        print("         python tool/configure_fluidnc_wifi.py")
        sys.exit(1)

    configure_fluidnc(port)
