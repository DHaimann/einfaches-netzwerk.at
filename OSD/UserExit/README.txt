Author:
  Dietmar Haimann
  
Configure:
  1. Add / remove the models you need in the xml file
  2. Configure your MDT Database
  3. Configure MDT database described perfectly fine by Mike Terrill
  https://miketerrill.net/2017/09/10/configuration-manager-dynamic-drivers-bios-management-with-total-control-part-1/
  https://miketerrill.net/2017/09/17/configuration-manager-dynamic-drivers-bios-management-with-total-control-part-2/

  4. Go to the Make and Model table
  5. Create entries that according to the entries in the xml file e.g.
    Make: HP
    Model: 800G1DM
    Make: HP
    Model: 800G1TWR
    Make: Dell
    Model: L5490
    ...
    
  6. Add the PackageIds to the Details pane e.g.
    W10x64DriverPackageID > PS100AB1
    BIOSUpdatePackageID   > PS100AB2
    SSMDriverPackageID    > PS100AB3

  7. Add the sections from CustomSettings.ini into yours
    The important lines are at the bottom of the file to make this working
      Parameters=ModelAlias
      ModelAlias=Model

  8. Add the xml and vbs files into your MDT files package (and update DP ;-)
  9. Run a Gather Task Sequence step and process rules in CustomSettings.ini
  
That way you are able to add more BaseBoard products to a single Model e.g.
  HP EliteDesk G2 Mini 65W          > 8056 > 800G2DM
  HP EliteDesk G2 Mini 65W          > 8055 > 800G2DM
  HP EliteDesk G2 Mini              > 8056 > 800G2DM
  HP EliteDesk G2 DM 65W            > 8056 > 800G2DM
  HP EliteDesk G2 Desktop Mini      > 8056 > 800G2DM
  HP EliteDesk G2 Desktop Mini 65W  > 8056 > 800G2DM

Now you are able to add a new model without touching the Task Sequence.
  
Thanks to:
  Mike Terrill [MVP]
    @miketerrill
    https://miketerrill.net/2017/09/10/configuration-manager-dynamic-drivers-bios-management-with-total-control-part-1/
    https://miketerrill.net/2017/09/17/configuration-manager-dynamic-drivers-bios-management-with-total-control-part-2/
  
  Michael Niehaus
    @mniehaus
    https://blogs.technet.microsoft.com/mniehaus/2009/07/17/querying-the-mdt-database-using-a-custom-model/
    
  Martin Modin
    https://blogs.technet.microsoft.com/mmodin/2010/02/03/how-to-extend-the-mdt-2010-database-with-custom-settings/
    
  and so many more...
