import torch
import torch.nn as nn
import torch.nn.functional as F
from typing import Dict, Tuple

class FactorioAgent(nn.Module):
    def __init__(
        self,
        grid_size: int = 32,
        num_channels: int = 3,
        hidden_dim: int = 256,
        num_action_types: int = 5  # move, build, mine, craft, research
    ):
        super().__init__()
        
        # Visual processing
        self.visual_encoder = nn.Sequential(
            # Input: (batch, channels, grid_height, grid_width, cell_size, cell_size)
            nn.Conv3d(num_channels, 32, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.MaxPool3d(2),
            
            nn.Conv3d(32, 64, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.MaxPool3d(2),
            
            nn.Conv3d(64, 128, kernel_size=3, padding=1),
            nn.ReLU(),
            nn.AdaptiveAvgPool3d((4, 4, 4)),  # Reduce to fixed size
            
            nn.Flatten()
        )
        
        # Calculate flattened size
        self.flat_size = 128 * 4 * 4 * 4
        
        # Action prediction heads
        self.action_type = nn.Sequential(
            nn.Linear(self.flat_size, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, num_action_types)
        )
        
        # Position prediction (x, y coordinates)
        self.position = nn.Sequential(
            nn.Linear(self.flat_size, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 2)  # x, y coordinates
        )
        
        # Additional parameters (direction, item type, etc)
        self.parameters = nn.Sequential(
            nn.Linear(self.flat_size, hidden_dim),
            nn.ReLU(),
            nn.Linear(hidden_dim, 64)  # Adjust size based on parameter space
        )
        
    def forward(self, visual_input: torch.Tensor) -> Dict[str, torch.Tensor]:
        """
        Forward pass of the model.
        
        Args:
            visual_input: Tensor of shape (batch, channels, grid_height, grid_width, cell_size, cell_size)
            
        Returns:
            Dictionary containing:
                - action_type: Predicted action type logits
                - position: Predicted x,y coordinates
                - parameters: Additional action parameters
        """
        # Extract visual features
        visual_features = self.visual_encoder(visual_input)
        
        # Predict action components
        return {
            'action_type': self.action_type(visual_features),
            'position': self.position(visual_features),
            'parameters': self.parameters(visual_features)
        }
    
    def predict_action(self, visual_input: torch.Tensor) -> Dict:
        """
        Predict a single action given the current state.
        """
        self.eval()
        with torch.no_grad():
            predictions = self(visual_input)
            
            # Convert logits to predictions
            action_type = F.softmax(predictions['action_type'], dim=-1)
            position = predictions['position']
            parameters = predictions['parameters']
            
            return {
                'action_type': action_type.argmax(-1),
                'position': position,
                'parameters': parameters
            }

def train_step(
    model: FactorioAgent,
    batch: Tuple[torch.Tensor, Dict],
    optimizer: torch.optim.Optimizer
) -> Dict[str, float]:
    """
    Single training step.
    
    Args:
        model: The FactorioAgent model
        batch: Tuple of (visual_input, action_dict)
        optimizer: The optimizer
        
    Returns:
        Dict of loss values
    """
    model.train()
    optimizer.zero_grad()
    
    visual_input, action_dict = batch
    
    # Forward pass
    predictions = model(visual_input)
    
    # Calculate losses
    action_loss = F.cross_entropy(
        predictions['action_type'],
        action_dict['action_type']
    )
    
    position_loss = F.mse_loss(
        predictions['position'],
        action_dict['position']
    )
    
    parameter_loss = F.mse_loss(
        predictions['parameters'],
        action_dict['parameters']
    )
    
    # Combine losses
    total_loss = action_loss + position_loss + parameter_loss
    
    # Backward pass
    total_loss.backward()
    optimizer.step()
    
    return {
        'total_loss': total_loss.item(),
        'action_loss': action_loss.item(),
        'position_loss': position_loss.item(),
        'parameter_loss': parameter_loss.item()
    }

if __name__ == "__main__":
    # Example usage
    model = FactorioAgent()
    
    # Create dummy batch
    batch_size = 4
    grid_height = 10
    grid_width = 10
    cell_size = 32
    channels = 3
    
    dummy_input = torch.randn(
        batch_size, channels, grid_height, grid_width, cell_size, cell_size
    )
    
    # Test forward pass
    outputs = model(dummy_input)
    print("Model outputs:", outputs.keys())
    for k, v in outputs.items():
        print(f"{k} shape:", v.shape)