terraform { 
  cloud { 
    
    organization = "Gameshow" 

    workspaces { 
      name = "Backend_ECS" 
    } 
  } 
}
