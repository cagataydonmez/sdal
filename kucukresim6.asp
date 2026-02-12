<%
iwidth = request.querystring("iwidth")
iheight = request.querystring("iheight")
resim = request.querystring("r")


set img = server.createobject("W3Image.Image")

img.LoadImage("C:\Domains\sdal.org\wwwroot\vesikalik\"&resim)


if not len(iwidth) = 0 then
w = img.Width
iwidth = cInt(iwidth)
if (w <> iwidth) then
imgscale = CDbl(iwidth/w)
img.Scale 100*imgscale,0
end if
end if

if not len(iheight) = 0 then
h = img.Height
iheight = cInt(iheight)
if (h <> iheight) then
imgscale = CDbl(iheight/h)
img.Scale 100*imgscale,0
end if
end if

img.StreamImage Response,"JPG",24
%>