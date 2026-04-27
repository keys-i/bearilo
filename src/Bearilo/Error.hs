module Bearilo.Error (AppError (..), renderError) where

data AppError
  = AppError String
  deriving stock (Eq, Show)

renderError :: AppError -> String
renderError (AppError message) = message
