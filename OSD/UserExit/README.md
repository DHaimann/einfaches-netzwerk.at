Author:
  Dietmar Haimann
Configure:
  1. Configure your MDT Database
  2. Go to the Make and Model table
  3. Create entries that match
    Make: HP
    Model: 800G1DM
    
    Make: HP
    Model 800G1TWR
    
    ...
    
  Add the sections from CustomSettings.ini into yours
  Add the xml and vbs into your MDT files package (and update DP ;-)
  Run a Gather Task Sequence step and process rules in CustomSettings.ini
