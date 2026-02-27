import React from 'react';

const SocialSignUpButtons = () => {
    const handleSignUp = (provider) => {
        console.log(`Sign up with ${provider}`);
    };

    return (
        <div className="social-sign-up-buttons">
            <button onClick={() => handleSignUp('Google')} className="google-button">
                Sign Up with Google
            </button>
            <button onClick={() => handleSignUp('Facebook')} className="facebook-button">
                Sign Up with Facebook
            </button>
            <button onClick={() => handleSignUp('Twitter')} className="twitter-button">
                Sign Up with Twitter
            </button>
        </div>
    );
};

export default SocialSignUpButtons;