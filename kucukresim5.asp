<%
resim = request.querystring("r")


maxheight=50
maxwidth=50


set img = server.createobject("W3Image.Image")

img.LoadImage("C:\Domains\sdal.org\wwwroot\vesikalik\"&resim)


w = img.Width
h = img.Height
if w>maxwidth or h>maxheight then

if w > maxwidth then
	imgscale = CDbl(maxwidth/w)
	img.Scale 100*imgscale,0
end if
h = img.Height
if h>maxheight then
	imgscale = CDbl(maxheight/h)
	img.Scale 100*imgscale,0
end if

end if

img.StreamImage Response,"JPG",24
%>