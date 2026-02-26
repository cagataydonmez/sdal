function createRequest() {
   var request = false;
   try {
     request = new XMLHttpRequest();
   } catch (trymicrosoft) {
     try {
       request = new ActiveXObject("Msxml2.XMLHTTP");
     } catch (othermicrosoft) {
       try {
         request = new ActiveXObject("Microsoft.XMLHTTP");
       } catch (failed) {
         request = false;
       }  
     }
   }

   if (!request)
     alert("Error initializing XMLHttpRequest!");
   return request;
}

   function onlineukon() {
     request = createRequest();
     var url = "onlineuyekontrol.asp";
     url=url+"?sid="+Math.random();
     request.onreadystatechange = updatePage;
     request.open("GET", url, true);
     request.send(null);
   }

   function onlineukon2() {
     request2 = createRequest();
     var url = "onlineuyekontrol2.asp";
     url=url+"?sid="+Math.random();
     request2.onreadystatechange = updatePage2;
     request2.open("GET", url, true);
     request2.send(null);
   }

   function updatePage() {
     if (request.readyState == 4 || request.readyState=="complete")
       if (request.status == 200)
         document.getElementById("oukkutusu").innerHTML = request.responseText;
       else if (request.status == 404)
         document.getElementById("oukkutusu").innerHTML = "Request URL does not exist";
       else
         document.getElementById("oukkutusu").innerHTML = "Error: status code is " + request.status;

   }

   function updatePage2() {
     if (request2.readyState == 4 || request2.readyState=="complete")
       if (request2.status == 200)
         document.getElementById("onuyekutusu").innerHTML = request2.responseText;
       else if (request2.status == 404)
         document.getElementById("oukkutusu").innerHTML = "Request URL does not exist";

   }