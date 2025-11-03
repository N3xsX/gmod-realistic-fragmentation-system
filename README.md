## Creating your own fragments using RFS

You can create fragments using the following function:  
``RFS:CreateShrapnell(int num, vector pos, boolean isBullets, boolean isMixed)``  

When ``isBullets`` if set to true, the explosion will use bullets; otherwise, it will use traces  
When ``isMixed`` if set to true, it will use both methods based on the server cVar configuration  

>Note: Bullet damage, ratio, distance, and other parameters are automatically taken from the server’s cVar settings
