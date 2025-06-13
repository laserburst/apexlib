/**
 * @description It's responsible for mocking you. It's not very vicious, but what did you expect?
 */
public with sharing virtual class ViciousMockery implements HttpCalloutMock {
    protected Map<Integer, String> codeToBody = new Map<Integer, String> {
        100 => 'Please. One more bite and this pie is gonna come back up to say hello. [Mayrina, BG3]', //Continue
        200 => 'I`m on my way to the promised land, woo! I`m on the highway to hell! [AC/DC]', //OK
        201 => 'By doom and dusk, I strike thy name from the archives. Rise! [Withers, BG3]', //Created
        300 => 'And being able to walk in the sunlight opens a lot of doors for me. Maybe some coffins too. [Astarion, BG3]', //Multiple Choices
        305 => 'One does not simply walk into Mordor. [Boromir, LoTR]', //Use Proxy
        400 => 'What do you mean? Do you mean to wish me a good morning or do you mean that it is a good morning whether I want it or not? Or perhaps you mean to say that you feel good on this particular morning. Or are you simply stating that this is a morning to be good on? [Gandalf, The Hobbit]', //Bad Request
        401 => 'Do they have a code clearance? [Vader, SW]', //Unauthorized
        402 => 'I need a dollar, dollar, dollar, that`s what I need (hey, hey) [Aloe Blacc]', //Payment Required
        403 => 'You shall not pass! [You know]', //Forbidden
        404 => '', //Not Found (no kidding)
        408 => 'Where`d you complete your training? School of the Snail? [Geralt, The Witcher]', //Request Timeout
        413 => 'Fascinating story. Any chance you`re nearing the end? [Geralt, The Witcher]', //Request Entity Too Large
        429 => 'I understand that if any more words come pouring out your mouth, I`m gonna have to eat every chicken in this room. [The Hound, GoT]', //Too Many Requests
        500 => 'If I fall, don`t bring me back [Jon Snow, GoT]', //Internal Server Error
        504 => 'A wizard is never late, Frodo Baggins [Gandalf, LoTR]', //Gateway Timeout
        509 => 'Well, apparently there`s a limit. Somewhere between a nice summer`s day and the full, concentrated power of the sun! [Astarion, BG3]' //Bandwidth Limit Exceeded
    };

    protected Integer code;

    public ViciousMockery() {
    }

    public ViciousMockery(Integer code) {
        this.code = code == null ? 200 : code;
    }

    public HTTPResponse respond(HttpRequest request) {
        HttpResponse response = new HttpResponse();
        response.setStatusCode(this.code);
        response.setBody(this.getBody());
        return response;
    }

    public static void cast(Integer code) {
        if (Test.isRunningTest()) {
            Test.setMock(HttpCalloutMock.class, new ViciousMockery(code));
        }
    }

    // use the template method pattern to change the body
    protected virtual String getBody() {
        return this.codeToBody.get(this.code) ?? 'I find your lack of faith disturbing [Vader, SW]';
    }
}