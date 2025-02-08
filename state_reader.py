from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import json, time, mss, mss.tools, os

STATE_FILE = '../../script-output/factorio_state_changes.json'
MAX_RETRIES = 5
RETRY_DELAY = 0.05  # 50ms delay


class StateHandler(FileSystemEventHandler):
    def __init__(self):
        self.last_processed_time = 0
        self.last_state = None
        
    def on_modified(self, event):
        if not event.is_directory and os.path.basename(event.src_path) == os.path.basename(STATE_FILE):
            current_time = time.time()
            if current_time - self.last_processed_time < 0.1:
                return
            
            self.last_processed_time = current_time
            
            # for attempt in range(MAX_RETRIES):
            #     try:
            #         with open(event.src_path, 'r') as f:
            #             state = json.load(f)
            #         break  # Success, exit loop
            #     except json.JSONDecodeError:
            #         if attempt < MAX_RETRIES - 1:
            #             time.sleep(RETRY_DELAY)  # Wait and retry
            #         else:
            #             print("Error reading state file after multiple attempts.")
            #             return
            #     except Exception as e:
            #         print(f"Error processing state: {e}")
            #         return

            try:
                with open(STATE_FILE, "r") as f:
                    state = json.load(f)
                tick = state.get("tick", int(time.time()))
            except Exception as e:
                tick = int(time.time())

            # Ensure the screencaps directory exists
            os.makedirs("screencaps", exist_ok=True)

            # Capture screenshot
            with mss.mss() as sct:
                monitor = sct.monitors[1] if len(sct.monitors) > 1 else sct.monitors[0]
                screenshot = sct.grab(monitor)
                filename = f"screencaps/screenshot_{tick}.png"
                mss.tools.to_png(screenshot.rgb, screenshot.size, output=filename)
                print(f"Captured screenshot: {filename}")
    
    def process_state(self, state):
        print(f"Tick: {state['tick']}")
        print(f"Player position: {state['player']['position']}")
        print(f"Visible entities: {len(state['visible_entities'])}")
        print("-" * 50)
        self.last_state = state

async def websocket_handler(websocket, path):
    observer = Observer()
    handler = StateHandler(websocket)
    observer.schedule(handler, ".", recursive=False)
    observer.start()

    try:
        async for message in websocket:
            command = json.loads(message)
            with open(COMMAND_FILE, "w") as f:
                json.dump(command, f)
    finally:
        observer.stop()
        observer.join()


def main():
    path = os.path.dirname(os.path.abspath(STATE_FILE))
    event_handler = StateHandler()
    observer = Observer()
    observer.schedule(event_handler, path, recursive=False)
    observer.start()

    start_server = websockets.serve(websocket_handler, "localhost", 8765)
    asyncio.get_event_loop().run_until_complete(start_server)
    asyncio.get_event_loop().run_forever()

    try:
        print(f"Watching {path} for Factorio state changes...")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        observer.join()

if __name__ == "__main__":
    main()
