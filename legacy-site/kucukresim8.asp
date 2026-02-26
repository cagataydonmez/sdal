<%
resim = request.querystring("r")


set img = server.createobject("W3Image.Image")

img.LoadImage("C:\Domains\sdal.org\wwwroot\foto0905\"&resim)

if img.width > 800 then

w = img.Width
iwidth = 800

imgscale = CDbl(iwidth/w)
img.Scale 100*imgscale,0

end if

if img.height > 554 then

h = img.Height
iheight = 554

imgscale = CDbl(iheight/h)
img.Scale 100*imgscale,0

end if

img.StreamImage Response,"JPG",24
%>