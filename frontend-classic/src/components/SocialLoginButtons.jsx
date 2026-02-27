import React from 'react';
import { GoogleLogin } from 'react-google-login';
import { FacebookLogin } from 'react-facebook-login-component';
import { TwitterLogin } from 'react-twitter-auth';

const SocialLoginButtons = () => {
    const onGoogleSuccess = (response) => {
        console.log('Google login success:', response);
    };

    const onGoogleFailure = (response) => {
        console.error('Google login failed:', response);
    };

    const onFacebookResponse = (response) => {
        console.log('Facebook login success:', response);
    };

    const onTwitterResponse = (response) => {
        console.log('Twitter login success:', response);
    };

    return (
        <div className="social-login-buttons">
            <GoogleLogin
                onSuccess={onGoogleSuccess}
                onFailure={onGoogleFailure}
                buttonText="Login with Google"
            />
            <FacebookLogin
                socialId="yourFacebookAppID"
                language="en_US"
                scope="public_profile,email"
                responseHandler={onFacebookResponse}
                xfbml={true}
                version="v2.5"
                class="facebook-login"
            />
            <TwitterLogin
                loginUrl="/api/v1/auth/twitter"
                onFailure={onTwitterResponse}
                requestTokenUrl="/api/v1/auth/twitter/reverse"
                className="twitter-login"
            />
        </div>
    );
};

export default SocialLoginButtons;