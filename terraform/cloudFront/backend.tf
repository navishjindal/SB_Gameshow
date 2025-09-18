terraform { 
  cloud { 
    
    organization = "Gameshow" 

    workspaces { 
      name = "Gameshow_CloudFront" 
    } 
  } 
}
