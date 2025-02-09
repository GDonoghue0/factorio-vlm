import json
from pathlib import Path
import pandas as pd
import numpy as np
from PIL import Image
from typing import Dict, List, Tuple
from itertools import chain


class FactorioDataProcessor:
    def __init__(self, data_dir: Path):
        self.data_dir = Path(data_dir)
        
    def load_state_changes(self) -> pd.DataFrame:
        """Load state changes from JSON file into DataFrame."""
        states = []
        with open(self.data_dir / "factorio_state_changes.json") as f:
            for line in f:
                states.append(json.loads(line))
        return pd.DataFrame(states)
    
    def load_actions(self) -> pd.DataFrame:
        """Load player actions from JSON file into DataFrame."""
        actions = []
        with open(self.data_dir / "player_actions.json") as f:
            for line in f:
                actions.append(json.loads(line))

        data = list(chain.from_iterable(actions))
        return pd.DataFrame(data)
    
    def load_screenshots(self) -> Dict[int, str]:
        """Load mapping of ticks to screenshot paths."""
        screenshots = {}
        for img_path in self.data_dir.glob("state_*.jpg"):
            tick = int(img_path.stem.split('_')[1])
            screenshots[tick] = str(img_path)
        return screenshots
    
    def align_data(self) -> List[Dict]:
        """Align states, actions, and screenshots by tick."""
        states_df = self.load_state_changes()
        actions_df = self.load_actions()
        screenshots = self.load_screenshots()
        
        # Group actions by the state tick they fall between
        aligned_data = []
        
        # Sort states by tick
        states_df = states_df.sort_values('tick')
        
        # Process each state tick
        for i in range(len(states_df) - 1):
            current_tick = states_df.iloc[i]['tick']
            next_tick = states_df.iloc[i + 1]['tick']
            
            # Get actions between current and next state
            tick_actions = actions_df[
                (actions_df['tick'] >= current_tick) & 
                (actions_df['tick'] < next_tick)
            ].to_dict('records')
            
            # Only include if we have both state and screenshot
            if current_tick in screenshots:
                aligned_data.append({
                    'tick': current_tick,
                    'state': states_df.iloc[i].to_dict(),
                    'screenshot_path': screenshots[current_tick],
                    'actions': tick_actions
                })
        
        return aligned_data
    
    def convert_to_grid(self, screenshot: Image.Image, grid_size: int = 32) -> np.ndarray:
        """Convert a screenshot into a grid of cells.
        
        Args:
            screenshot: PIL Image of the screenshot
            grid_size: Size of each grid cell in pixels
            
        Returns:
            numpy array of shape (grid_height, grid_width, channels)
        """
        # Convert to numpy array
        img_array = np.array(screenshot)
        
        # Calculate grid dimensions
        height, width = img_array.shape[:2]
        grid_height = height // grid_size
        grid_width = width // grid_size
        
        # Resize to exact multiple of grid size if needed
        if height % grid_size != 0 or width % grid_size != 0:
            new_height = grid_height * grid_size
            new_width = grid_width * grid_size
            img_array = img_array[:new_height, :new_width]
        
        # Reshape into grid cells
        # Result shape: (grid_height, grid_width, grid_size, grid_size, channels)
        grid = img_array.reshape(grid_height, grid_size, grid_width, grid_size, -1)
        grid = np.moveaxis(grid, 2, 1)  # Rearrange to get cells properly aligned
        
        return grid

    def create_training_examples(self, grid_size: int = 32) -> List[Tuple]:
        """Create (state, grid_screenshot, actions) training examples."""
        aligned_data = self.align_data()
        
        training_examples = []
        for data in aligned_data:
            # Load and process screenshot
            screenshot = Image.open(data['screenshot_path'])
            grid_screenshot = self.convert_to_grid(screenshot, grid_size)
            
            training_examples.append((
                data['state'],
                grid_screenshot,
                data['actions']
            ))
            
        return training_examples

if __name__ == "__main__":
    # Example usage
    processor = FactorioDataProcessor(Path("/Users/geoff/Library/Application Support/factorio/script-output"))
    examples = processor.create_training_examples()
    print(f"Created {len(examples)} training examples")
    
    # Print sample example structure
    if examples:
        state, screenshot, actions = examples[10]
        print("\nSample example:")
        print(f"State tick: {state['tick']}")
        print(f"Screenshot size: {screenshot.size}")
        print(f"Number of actions: {len(actions)}")