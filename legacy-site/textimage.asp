<%
Sub imagetext(msgcode)

 ' Create an error image
 Dim errorimage
 Dim fontobj
 Dim width
 Dim height

 Set errorimage = Server.CreateObject("W3Image.Image")
 errorimage.CreateEmptySurface 1,1

 ' Create and select the font
 Set fontobj = errorimage.CreateFont("Forte",35,0,"bold",0,errorimage.CreateColor("#663300"),False,False,True)
 errorimage.SetFont fontobj

 ' Get size of the text
 width = errorimage.GetTextWidth(msgcode)
 height = errorimage.GetTextHeight(msgcode)

 ' Create a surface as large as the error message
 errorimage.CreateEmptySurface width,height

set brushobj = errorimage.CreateSolidBrush(errorimage.CreateColor("#ffffcc"))
errorimage.SetBrush brushobj

errorimage.FloodFill 0,0,&HFFFFCC

 ' Select the font again (font is deselected when creating a new surface)
 errorimage.SetFont fontobj

 ' Write out error message
 errorimage.DrawText msgcode,0,0

 ' Stream the image
 errorimage.StreamImage Response, "JPG", 24

End Sub


imagetext("cagatay")

%>