<%
resim = request.querystring("r")


set img = server.createobject("W3Image.Image")

img.LoadImage("C:\Domains\sdal.org\wwwroot\vesikalik\"&resim)

if img.width > 1300 then

w = img.Width
iwidth = 1300

imgscale = CDbl(iwidth/w)
img.Scale 100*imgscale,0

end if

img.StreamImage Response,"JPG",24
%>