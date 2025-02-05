from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import json
import time
from pathlib import Path

class StateHandler(FileSystemEventHandler):
    def __init__(self):
        self.last_processed_time = 0
        self.last_state = None
        
    def on_modified(self, event):
        if not event.is_directory and event.src_path.endswith('factorio_state.json'):
            # Debounce rapid updates
            current_time = time.time()
            if current_time - self.last_processed_time < 0.1:
                return
            
            self.last_processed_time = current_time
            
            try:
                with open(event.src_path, 'r') as f:
                    state = json.load(f)
                    self.process_state(state)
            except json.JSONDecodeError:
                print("Error reading state file - might have caught it during writing")
                return
            except Exception as e:
                print(f"Error processing state: {e}")
                return
    
    def process_state(self, state):
        # Here's where we'll process the state for our VLM
        # For now, just print some basic info
        print(f"Tick: {state['tick']}")
        print(f"Player position: {state['player']['position']}")
        print(f"Visible entities: {len(state['visible_entities'])}")
        print("-" * 50)
        
        self.last_state = state

def main():
    # Create observer and handler
    path = "."  # Watch current directory
    event_handler = StateHandler()
    observer = Observer()
    observer.schedule(event_handler, path, recursive=False)
    observer.start()

    try:
        print("Watching for Factorio state changes...")
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
        observer.join()

if __name__ == "__main__":
    main()