import time
import socket
import subprocess

TARGET_IP = "192.168.137.100"
PORT = 80

print(f"Monitoring {TARGET_IP}:{PORT} for ESP32 connection...")
start = time.time()
found = False

while time.time() - start < 30:
    # 1. Try TCP connect
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.5)
    try:
        res = s.connect_ex((TARGET_IP, PORT))
        if res == 0:
            print(f"\n[SUCCES] ESP32 CONNECTE ! Port {PORT} ouvert sur {TARGET_IP} !")
            found = True
            s.close()
            break
    except Exception:
        pass
    s.close()

    # 2. Check ARP table
    try:
        out = subprocess.check_output("arp -a", shell=True).decode("latin-1", errors="ignore")
        if TARGET_IP in out:
            print(f"\n[ARP DETECTE] {TARGET_IP} est present dans la table ARP !")
            found = True
            break
    except Exception:
        pass

    print(".", end="", flush=True)
    time.sleep(1)

if not found:
    print(f"\n[TIMEOUT] L'ESP32 n'a pas ete detecte sur {TARGET_IP} pendant les 30 dernieres secondes.")

