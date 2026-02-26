var xmlHttp;

function hmesajisle(str)
{

xmlHttp=GetXmlHttpObject()
if (xmlHttp==null)
{
alert ("Browser HTTP Request")
return
} 

var url="hmesisle.asp"
url=url+"?mes="+encodeURI(str)
url=url+"&sid="+Math.random()
xmlHttp.onreadystatechange=stateChanged
xmlHttp.open("GET",url,true)
xmlHttp.send(null)
} 


function stateChanged() 
{ 
if (xmlHttp.readyState==4 || xmlHttp.readyState=="complete")
{ 
document.getElementById("hmkutusu").innerHTML=xmlHttp.responseText
} 
}

function GetXmlHttpObject()
{ 
var objXMLHttp=null

if (window.XMLHttpRequest)
{
objXMLHttp=new XMLHttpRequest()
}
else if (window.ActiveXObject)
{
objXMLHttp=new ActiveXObject("Microsoft.XMLHTTP")
}
return objXMLHttp
}