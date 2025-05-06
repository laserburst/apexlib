/**
 * @description It holds example data structures that may be returned by API.
 * @team Laserburst 
 */
public with sharing class ExampleResponse {

    // Error
    public class Error implements CalloutErrorResponse {
        public ErrorDetail error;

        public String getErrorMessage() {
            if (error == null) {
                return 'Example response error is null';
            }
            return error.getErrorMessage();
        }
    }

    public class ErrorDetail {
        public String code;
        public String code_message;
        public List<MessageDetail> messages;

        public String getErrorMessage() {
            String baseMessage = String.isNotBlank(code_message) ? code_message : 'Example response error';
    
            if (messages == null || messages?.isEmpty()) {
                return baseMessage + ' with no detail';
            }

            List<String> details = new List<String>();
            for (MessageDetail message : messages) {
                if (message != null) {
                    String detail = message.getErrorMessage();
                    if (String.isNotBlank(detail)) {
                        details.add(detail);
                    }
                } else {
                    details.add('No detail');
                }
            }
            return baseMessage + ' - ' + String.join(details, '; ');
        }
    }

    public class MessageDetail {
        public String field;
        public String code;
        public String code_message;

        public String getErrorMessage() {
            String detail = '';
            if (String.isNotBlank(field)) {
                detail += 'Field "' + field + '": ';
            }
            if (String.isNotBlank(code_message)) {
                detail += code_message;
            }
            return detail;
        }
    }

    // DialogToken
    public class DialogToken {
        public DialogTokenData data;
    }

    public class DialogTokenData {
        public String dialog_token;
    }
    
}