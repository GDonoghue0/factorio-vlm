import time
from rcon.source import Client
import socket


import json

class FactorioController:
    def __init__(self, host='localhost', port=25575, password='test123'):
        self.host = host
        self.port = port
        self.password = password

    def send_command(self, command):
        with Client(host=self.host, port=self.port, passwd=self.password) as client:
            response = client.run(f'/c {command}')
        print(response)
        return response

    def move_north(self):
        return self.send_command('remote.call("factorio_ai", "move", "north")')
        
    def stop_moving(self):
        return self.send_command('remote.call("factorio_ai", "move", "stop")')
            
    def test_connection(self):
        return self.send_command('remote.call("factorio_ai", "test_command")')


    def test_factorio_commands(self):
    try:
        print("\nAttempting RCON connection...")
        with Client('127.0.0.1', port=25575, passwd='test123') as client:
            print("Connected successfully!")
            
            # Test 1: Basic game command
            print("\nTest 1: Basic game time command")
            resp = client.run('/time')
            print(f"Time response: {resp}")
            
            # Test 2: Direct Lua command
            print("\nTest 2: Direct Lua print")
            resp = client.run('/c game.print("Testing Lua execution")')
            print(f"Lua print response: {resp}")
            
            # Test 3: List available interfaces
            print("\nTest 3: List remote interfaces")
            resp = client.run('/c local interfaces = {} for name,_ in pairs(remote.interfaces) do table.insert(interfaces, name) end game.print(serpent.line(interfaces))')
            print(f"Available interfaces: {resp}")
            
            # Test 4: Check if our mod is loaded
            print("\nTest 4: Check loaded mods")
            resp = client.run('/c game.print(serpent.line(game.active_mods))')
            print(f"Active mods: {resp}")
            
            # Test 5: Try to directly move the player
            print("\nTest 5: Direct player movement")
            resp = client.run('/c local p = game.players[1] if p then p.walking_state = {walking = true, direction = defines.direction.north} end')
            print(f"Direct movement response: {resp}")
            
    except Exception as e:
        print(f"RCON test failed: {e}")

    def test_rcon_connection(self):
        print("Starting RCON test...")
        
        # First test raw socket connection
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            print("Testing port connection...")
            result = sock.connect_ex(('127.0.0.1', 25575))
            if result == 0:
                print("Port 25575 is open")
            else:
                print(f"Port connection failed with error: {result}")
            sock.close()
        except Exception as e:
            print(f"Socket test failed: {e}")
            return

        # Try RCON connection with mcrcon
        try:
            print("\nAttempting RCON connection...")
            with Client(host="127.0.0.1", passwd="test123", port=25575) as mcr:
                print("Connected successfully!")
                time.sleep(1)  # Give the connection a moment to stabilize
                
                print("\nTesting /time command...")
                resp = mcr.run("/time")
                print(f"Response: {resp}")
                
                time.sleep(1)
                
                print("\nTesting simple Lua command...")
                resp = mcr.run("/c game.print('RCON test')")
                print(f"Response: {resp}")
                
        except Exception as e:
            print(f"RCON test failed: {e}")


if __name__ == "__main__":
    controller = FactorioController()
    print(controller.test_factorio_commands())
    # print(controller.test_rcon_connection())
    # print(controller.test_connection())

    controller = FactorioController()
    while True:
        print("Moving north...")
        controller.move_north()
        # Wait a few seconds then stop
        time.sleep(3)
        print("Stopping...")
        controller.stop_moving()
        time.sleep(3)