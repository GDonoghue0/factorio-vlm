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
            with Client('127.0.0.1', 25575, passwd='test123') as client:
                print("Connected successfully!")
                
                # Test 1: Basic game command
                print("\nTest 1: Basic game time command")
                resp = client.run('/time')
                print(f"Time response: {resp}")
                
                # Test 2: Different Lua command formats
                print("\nTest 2a: Silent command")
                resp = client.run('/silent-command game.print("Test silent")')
                print(f"Silent command response: {resp}")
                
                print("\nTest 2b: Alternative print")
                resp = client.run('/silent-command local p = game.print("Test print") return p')
                print(f"Alternative print response: {resp}")
                
                # Test 3: Check game version
                print("\nTest 3: Game version")
                resp = client.run('/silent-command return helpers.version')
                print(f"Game version: {resp}")
                
                # Test 4: Get player info
                print("\nTest 4: Player info")
                resp = client.run('/silent-command return helpers.table_to_json({name=game.players[1].name, position=game.players[1].position})')
                print(f"Player info: {resp}")
                
                # Test 5: List mods differently
                print("\nTest 5: Mods list")
                resp = client.run('/silent-command return helpers.table_to_json(helpers.active_mods)')
                print(f"Mods list: {resp}")
                
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